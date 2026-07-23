package com.hamid.droidforge.agent;

import java.lang.instrument.ClassFileTransformer;
import java.lang.instrument.Instrumentation;
import java.security.ProtectionDomain;

import jdk.internal.org.objectweb.asm.ClassReader;
import jdk.internal.org.objectweb.asm.ClassVisitor;
import jdk.internal.org.objectweb.asm.ClassWriter;
import jdk.internal.org.objectweb.asm.MethodVisitor;
import jdk.internal.org.objectweb.asm.Opcodes;

public final class DroidForgeAapt2Agent {
    private static final String MAVEN_COMPANION_CLASS =
            "com/android/build/gradle/internal/res/Aapt2FromMaven$Companion";

    private static final String DAEMON_SERVICE_CLASS =
            "com/android/build/gradle/internal/services/Aapt2DaemonBuildService";

    private static final String PACKAGED_AAPT2_FILENAME =
            "libdroidforge_aapt2_shim.so";

    private DroidForgeAapt2Agent() {
    }

    public static void premain(
            String arguments,
            Instrumentation instrumentation
    ) {
        System.err.println(
                "[DroidForge AAPT2 Agent] "
                        + "AGP AAPT2 override compatibility enabled"
        );

        instrumentation.addTransformer(new ClassFileTransformer() {
            @Override
            public byte[] transform(
                    Module module,
                    ClassLoader loader,
                    String className,
                    Class<?> classBeingRedefined,
                    ProtectionDomain protectionDomain,
                    byte[] classfileBuffer
            ) {
                if (
                        !MAVEN_COMPANION_CLASS.equals(className)
                                && !DAEMON_SERVICE_CLASS.equals(className)
                ) {
                    return null;
                }

                try {
                    ClassReader reader = new ClassReader(classfileBuffer);
                    ClassWriter writer = new ClassWriter(reader, 0);

                    ClassVisitor visitor = new ClassVisitor(
                            Opcodes.ASM7,
                            writer
                    ) {
                        @Override
                        public MethodVisitor visitMethod(
                                int access,
                                String name,
                                String descriptor,
                                String signature,
                                String[] exceptions
                        ) {
                            MethodVisitor delegate = super.visitMethod(
                                    access,
                                    name,
                                    descriptor,
                                    signature,
                                    exceptions
                            );

                            final boolean patchOverrideValidation =
                                    MAVEN_COMPANION_CLASS.equals(className)
                                            && "create".equals(name);

                            final boolean patchExecutableResolution =
                                    DAEMON_SERVICE_CLASS.equals(className)
                                            && "getAapt2ExecutablePath".equals(name);

                            if (
                                    !patchOverrideValidation
                                            && !patchExecutableResolution
                            ) {
                                return delegate;
                            }

                            return new MethodVisitor(
                                    Opcodes.ASM7,
                                    delegate
                            ) {
                                @Override
                                public void visitFieldInsn(
                                        int opcode,
                                        String owner,
                                        String fieldName,
                                        String fieldDescriptor
                                ) {
                                    boolean isAapt2FilenameConstant =
                                            opcode == Opcodes.GETSTATIC
                                                    && "com/android/SdkConstants"
                                                    .equals(owner)
                                                    && "FN_AAPT2"
                                                    .equals(fieldName)
                                                    && "Ljava/lang/String;"
                                                    .equals(fieldDescriptor);

                                    if (!isAapt2FilenameConstant) {
                                        super.visitFieldInsn(
                                                opcode,
                                                owner,
                                                fieldName,
                                                fieldDescriptor
                                        );
                                        return;
                                    }

                                    if (patchOverrideValidation) {
                                        /*
                                         * Aapt2FromMaven normally requires the
                                         * override path to end in "aapt2".
                                         * Android packaged executables use a
                                         * native-library .so filename.
                                         */
                                        super.visitLdcInsn(".so");
                                        return;
                                    }

                                    /*
                                     * Aapt2DaemonBuildService normally resolves:
                                     *
                                     *     binaryDirectory/aapt2
                                     *
                                     * Resolve the actual packaged native executable
                                     * instead:
                                     *
                                     *     binaryDirectory/
                                     *     libdroidforge_aapt2_shim.so
                                     */
                                    super.visitLdcInsn(
                                            PACKAGED_AAPT2_FILENAME
                                    );
                                }
                            };
                        }
                    };

                    reader.accept(visitor, 0);

                    if (MAVEN_COMPANION_CLASS.equals(className)) {
                        System.err.println(
                                "[DroidForge AAPT2 Agent] "
                                        + "Patched Aapt2FromMaven Companion"
                        );
                    } else {
                        System.err.println(
                                "[DroidForge AAPT2 Agent] "
                                        + "Patched Aapt2DaemonBuildService"
                        );
                    }

                    return writer.toByteArray();
                } catch (Throwable error) {
                    System.err.println(
                            "[DroidForge AAPT2 Agent] "
                                    + "Transformation failed for "
                                    + className
                                    + ": "
                                    + error
                    );
                    error.printStackTrace(System.err);
                    return null;
                }
            }
        });
    }
}

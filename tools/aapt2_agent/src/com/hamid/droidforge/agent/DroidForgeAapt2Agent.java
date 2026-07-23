package com.hamid.droidforge.agent;

import java.lang.instrument.ClassFileTransformer;
import java.lang.instrument.Instrumentation;
import java.security.ProtectionDomain;
import java.util.ArrayList;
import java.util.List;

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

    private static final String DAEMON_IMPL_CLASS =
            "com/android/builder/internal/aapt/v2/Aapt2DaemonImpl";

    private static final String AGENT_INTERNAL_NAME =
            "com/hamid/droidforge/agent/DroidForgeAapt2Agent";

    private static final String PACKAGED_AAPT2_FILENAME =
            "libdroidforge_aapt2_shim.so";

    private static final String ANDROID_LINKER =
            "/system/bin/linker64";

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
                                && !DAEMON_IMPL_CLASS.equals(className)
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

                            final boolean patchProcessLaunch =
                                    DAEMON_IMPL_CLASS.equals(className)
                                            && "startProcess".equals(name);

                            if (
                                    !patchOverrideValidation
                                            && !patchExecutableResolution
                                            && !patchProcessLaunch
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
                                        super.visitLdcInsn(".so");
                                        return;
                                    }

                                    if (patchExecutableResolution) {
                                        super.visitLdcInsn(
                                                PACKAGED_AAPT2_FILENAME
                                        );
                                        return;
                                    }

                                    super.visitFieldInsn(
                                            opcode,
                                            owner,
                                            fieldName,
                                            fieldDescriptor
                                    );
                                }

                                @Override
                                public void visitMethodInsn(
                                        int opcode,
                                        String owner,
                                        String methodName,
                                        String methodDescriptor,
                                        boolean isInterface
                                ) {
                                    boolean isProcessBuilderConstructor =
                                            patchProcessLaunch
                                                    && opcode == Opcodes.INVOKESPECIAL
                                                    && "java/lang/ProcessBuilder"
                                                    .equals(owner)
                                                    && "<init>".equals(methodName)
                                                    && "(Ljava/util/List;)V"
                                                    .equals(methodDescriptor);

                                    if (isProcessBuilderConstructor) {
                                        /*
                                         * Stack before this call:
                                         *
                                         *     uninitialized ProcessBuilder
                                         *     original command List
                                         *
                                         * Replace the command list before invoking
                                         * the ProcessBuilder constructor.
                                         */
                                        super.visitMethodInsn(
                                                Opcodes.INVOKESTATIC,
                                                AGENT_INTERNAL_NAME,
                                                "prepareAapt2Command",
                                                "(Ljava/util/List;)Ljava/util/List;",
                                                false
                                        );
                                    }

                                    super.visitMethodInsn(
                                            opcode,
                                            owner,
                                            methodName,
                                            methodDescriptor,
                                            isInterface
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
                    } else if (DAEMON_SERVICE_CLASS.equals(className)) {
                        System.err.println(
                                "[DroidForge AAPT2 Agent] "
                                        + "Patched Aapt2DaemonBuildService"
                        );
                    } else {
                        System.err.println(
                                "[DroidForge AAPT2 Agent] "
                                        + "Patched Aapt2DaemonImpl process launch"
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

    public static List<String> prepareAapt2Command(
            List<String> originalCommand
    ) {
        if (
                originalCommand == null
                        || originalCommand.isEmpty()
        ) {
            return originalCommand;
        }

        String executable = originalCommand.get(0);

        if (
                executable == null
                        || !executable.endsWith(PACKAGED_AAPT2_FILENAME)
        ) {
            return originalCommand;
        }

        ArrayList<String> wrappedCommand =
                new ArrayList<>(originalCommand.size() + 2);

        wrappedCommand.add(ANDROID_LINKER);
        wrappedCommand.add(executable);
        wrappedCommand.add(executable);

        for (int index = 1; index < originalCommand.size(); index++) {
            wrappedCommand.add(originalCommand.get(index));
        }

        System.err.println(
                "[DroidForge AAPT2 Agent] Launch command: "
                        + wrappedCommand
        );

        return wrappedCommand;
    }
}

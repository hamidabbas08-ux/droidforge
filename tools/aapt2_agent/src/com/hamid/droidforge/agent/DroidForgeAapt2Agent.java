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

    private static final String DAEMON_IMPL_CLASS =
            "com/android/builder/internal/aapt/v2/Aapt2DaemonImpl";

    private static final String PACKAGED_AAPT2_FILENAME =
            "libdroidforge_aapt2_shim.so";

    private static final String ANDROID_LINKER =
            "/system/bin/linker64";

    private static final String INJECTED_HELPER =
            "droidforgePrepareAapt2Command";

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
                    ClassWriter writer = new ClassWriter(
                            reader,
                            ClassWriter.COMPUTE_MAXS
                    );

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
                                                    && opcode
                                                    == Opcodes.INVOKESPECIAL
                                                    && "java/lang/ProcessBuilder"
                                                    .equals(owner)
                                                    && "<init>".equals(methodName)
                                                    && "(Ljava/util/List;)V"
                                                    .equals(methodDescriptor);

                                    if (isProcessBuilderConstructor) {
                                        /*
                                         * Stack here:
                                         *
                                         *     uninitialized ProcessBuilder
                                         *     original command List
                                         *
                                         * Call the helper injected directly into
                                         * Aapt2DaemonImpl. This avoids referencing
                                         * the Java-agent class from AGP's classloader.
                                         */
                                        super.visitMethodInsn(
                                                Opcodes.INVOKESTATIC,
                                                DAEMON_IMPL_CLASS,
                                                INJECTED_HELPER,
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

                        @Override
                        public void visitEnd() {
                            if (DAEMON_IMPL_CLASS.equals(className)) {
                                injectCommandHelper();
                            }

                            super.visitEnd();
                        }

                        private void injectCommandHelper() {
                            MethodVisitor method = super.visitMethod(
                                    Opcodes.ACC_PRIVATE
                                            | Opcodes.ACC_STATIC
                                            | Opcodes.ACC_SYNTHETIC,
                                    INJECTED_HELPER,
                                    "(Ljava/util/List;)Ljava/util/List;",
                                    "(Ljava/util/List<Ljava/lang/String;>;)"
                                            + "Ljava/util/List<Ljava/lang/String;>;",
                                    null
                            );

                            method.visitCode();

                            /*
                             * ArrayList wrapped = new ArrayList(original);
                             */
                            method.visitTypeInsn(
                                    Opcodes.NEW,
                                    "java/util/ArrayList"
                            );
                            method.visitInsn(Opcodes.DUP);
                            method.visitVarInsn(Opcodes.ALOAD, 0);
                            method.visitMethodInsn(
                                    Opcodes.INVOKESPECIAL,
                                    "java/util/ArrayList",
                                    "<init>",
                                    "(Ljava/util/Collection;)V",
                                    false
                            );
                            method.visitVarInsn(Opcodes.ASTORE, 1);

                            /*
                             * wrapped.add(0, original.get(0));
                             *
                             * Original:
                             *   [shim, daemon]
                             *
                             * Becomes:
                             *   [shim, shim, daemon]
                             */
                            method.visitVarInsn(Opcodes.ALOAD, 1);
                            method.visitInsn(Opcodes.ICONST_0);
                            method.visitVarInsn(Opcodes.ALOAD, 0);
                            method.visitInsn(Opcodes.ICONST_0);
                            method.visitMethodInsn(
                                    Opcodes.INVOKEINTERFACE,
                                    "java/util/List",
                                    "get",
                                    "(I)Ljava/lang/Object;",
                                    true
                            );
                            method.visitMethodInsn(
                                    Opcodes.INVOKEVIRTUAL,
                                    "java/util/ArrayList",
                                    "add",
                                    "(ILjava/lang/Object;)V",
                                    false
                            );

                            /*
                             * wrapped.add(0, "/system/bin/linker64");
                             *
                             * Final:
                             *   [linker64, shim, shim, daemon]
                             */
                            method.visitVarInsn(Opcodes.ALOAD, 1);
                            method.visitInsn(Opcodes.ICONST_0);
                            method.visitLdcInsn(ANDROID_LINKER);
                            method.visitMethodInsn(
                                    Opcodes.INVOKEVIRTUAL,
                                    "java/util/ArrayList",
                                    "add",
                                    "(ILjava/lang/Object;)V",
                                    false
                            );

                            method.visitFieldInsn(
                                    Opcodes.GETSTATIC,
                                    "java/lang/System",
                                    "err",
                                    "Ljava/io/PrintStream;"
                            );
                            method.visitVarInsn(Opcodes.ALOAD, 1);
                            method.visitMethodInsn(
                                    Opcodes.INVOKESTATIC,
                                    "java/lang/String",
                                    "valueOf",
                                    "(Ljava/lang/Object;)Ljava/lang/String;",
                                    false
                            );
                            method.visitInvokeDynamicInsn(
                                    "makeConcatWithConstants",
                                    "(Ljava/lang/String;)Ljava/lang/String;",
                                    new jdk.internal.org.objectweb.asm.Handle(
                                            Opcodes.H_INVOKESTATIC,
                                            "java/lang/invoke/StringConcatFactory",
                                            "makeConcatWithConstants",
                                            "("
                                                    + "Ljava/lang/invoke/MethodHandles$Lookup;"
                                                    + "Ljava/lang/String;"
                                                    + "Ljava/lang/invoke/MethodType;"
                                                    + "Ljava/lang/String;"
                                                    + "[Ljava/lang/Object;"
                                                    + ")Ljava/lang/invoke/CallSite;",
                                            false
                                    ),
                                    "[DroidForge AAPT2 Agent] Launch command: \u0001"
                            );
                            method.visitMethodInsn(
                                    Opcodes.INVOKEVIRTUAL,
                                    "java/io/PrintStream",
                                    "println",
                                    "(Ljava/lang/String;)V",
                                    false
                            );

                            method.visitVarInsn(Opcodes.ALOAD, 1);
                            method.visitInsn(Opcodes.ARETURN);

                            method.visitMaxs(0, 0);
                            method.visitEnd();
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
}

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
    private static final String TARGET_CLASS =
            "com/android/build/gradle/internal/res/Aapt2FromMaven$Companion";

    private DroidForgeAapt2Agent() {
    }

    public static void premain(String arguments, Instrumentation instrumentation) {
        System.err.println(
                "[DroidForge AAPT2 Agent] AGP AAPT2 override compatibility enabled"
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
                if (!TARGET_CLASS.equals(className)) {
                    return null;
                }

                try {
                    ClassReader reader = new ClassReader(classfileBuffer);
                    ClassWriter writer = new ClassWriter(reader, 0);

                    ClassVisitor visitor = new ClassVisitor(Opcodes.ASM7, writer) {
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

                            if (!"create".equals(name)) {
                                return delegate;
                            }

                            return new MethodVisitor(Opcodes.ASM7, delegate) {
                                @Override
                                public void visitFieldInsn(
                                        int opcode,
                                        String owner,
                                        String fieldName,
                                        String fieldDescriptor
                                ) {
                                    if (
                                            opcode == Opcodes.GETSTATIC
                                                    && "com/android/SdkConstants".equals(owner)
                                                    && "FN_AAPT2".equals(fieldName)
                                                    && "Ljava/lang/String;".equals(fieldDescriptor)
                                    ) {
                                        /*
                                         * AGP normally requires the custom executable path
                                         * to end with "aapt2". Android-packaged executables
                                         * must remain in nativeLibraryDir with a .so name.
                                         */
                                        super.visitLdcInsn(".so");
                                        return;
                                    }

                                    super.visitFieldInsn(
                                            opcode,
                                            owner,
                                            fieldName,
                                            fieldDescriptor
                                    );
                                }
                            };
                        }
                    };

                    reader.accept(visitor, 0);

                    System.err.println(
                            "[DroidForge AAPT2 Agent] Patched "
                                    + "Aapt2FromMaven Companion"
                    );

                    return writer.toByteArray();
                } catch (Throwable error) {
                    System.err.println(
                            "[DroidForge AAPT2 Agent] Transformation failed: "
                                    + error
                    );
                    error.printStackTrace(System.err);
                    return null;
                }
            }
        });
    }
}

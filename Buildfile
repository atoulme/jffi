
Java.classpath << "org.apache.ant:ant-nodeps:jar:1.8.0"
repositories.remote = ["http://repo1.maven.org/maven2"]

VERSION_NUMBER = "1.0.0.001-SNAPSHOT"


# Determines the CPU
# from the Ruby os.arch 
def determine_cpu
  RUBY_PLATFORM # very much TODO
end

# Returns the make executable
# depending on the OS
def make
  cpu = determine_cpu
  case 
  when cpu.match(/FreeBSD/) || cpu.match(/OpenBSD/) || cpu.match(/AIX/) then
    return "gmake"
  when cpu.match(/SunOS/)  then
    return "/usr/sfw/bin/gmake"
  else
    return "make"
  end
end
  
desc "JRuby FFI libraries"
define "jffi" do
  project.version = VERSION_NUMBER
  project.group = "org.jruby"
  compile.options.source = "1.5"
  compile.options.target = "1.5"
  compile.from(_("target/generated"), _('src')).into('target/classes')
  
  generate_version = file(_('target/generated/com/kenai/jffi/Version.java')) do |f|
    puts "Generating the version java file"
    mkdir_p File.dirname(f.to_s)
    File.open(f.to_s, "w") do |file|
      file.puts <<-FILE
package com.kenai.jffi;
public final class Version {
   private Version() {}
   public static final int MAJOR = #{VERSION_NUMBER.split('.')[0]};
   public static final int MINOR = #{VERSION_NUMBER.split('.')[1]};
   public static final int MICRO = #{VERSION_NUMBER.split('.')[2]};
}
FILE
    end
  end
  
  headers = file(_('target/native')) do
    puts "Compiling the target native headers"
    mkdir_p _("target/native")
    Buildr.ant('build-native-headers') do |ant|
      ant.javah :classpath => 'target/classes', :destdir => 'target/native', :force => 'yes' do
        ant.method_missing "class", :name => "com.kenai.jffi.Foreign"
        ant.method_missing "class",  :name => "com.kenai.jffi.ObjectBuffer"
        ant.method_missing "class",  :name => "com.kenai.jffi.Version"
      end
    end
  end
  

  native_compilation = file(_('target/cpp')).enhance [headers] do |cpp|
    puts "Compile the C files"
    mkdir_p cpp.to_s
    
    system "#{make} JAVA_HOME=$JAVA_HOME SRC_DIR='#{_('jni')}' JNI_DIR='#{_('jni')}' BUILDR_DIR='#{_('target/jni')}' CPU=#{determine_cpu} VERSION=#{VERSION_NUMBER.split('.')[0..1].to_s} USE_SYSTEM_LIBFFI=0 -f #{_('jni/GNUmakefile')}"

  end

  native_testlib = file(_('target/cpptest')).enhance [native_compilation] do |test|
    system "#{make} JAVA_HOME=$JAVA_HOME BUILDR_DIR='#{_('target')}' CPU=#{determine_cpu} -f #{_('libtest/GNUmakefile')}"
  end
  
  #build-platform-jar
  package(:jar, :classifier=>determine_cpu).tap do |jar|
    jar.include(_('target/native/jffi*.dll'), :path => "jni/#{determine_cpu}")
    jar.include(_('target/native/libjffi*.so'), :path => "jni/#{determine_cpu}")
    jar.include(_('target/native/libjffi*.jnilib'), :path => "jni/#{determine_cpu}")
    jar.include(_('target/native/libjffi*.dylib'), :path => "jni/#{determine_cpu}")
    jar.include(_('target/native/libjffi*.a'), :path => "jni/#{determine_cpu}")
  end
    
  
  
  # Copy the jar so that it can be committed.
  package(:jar).enhance do
    cp package(:jar, :classifier=>determine_cpu).to_s, "archive"
  end
  
  package(:jar).tap do |jar|
    #assemble-native-jar
    # we don't create native.jar, we move directly to merge.
    jar.merge("archive/jffi-Darwin.jar")
    jar.merge("archive/jffi-i386-Windows.jar")
    jar.merge("archive/jffi-i386-Linux.jar")
    jar.merge("archive/jffi-i386-SunOS.jar")
    jar.merge("archive/jffi-x86_64-SunOS.jar")
    jar.merge("archive/jffi-x86_64-Linux.jar")
    jar.merge("archive/jffi-s390x-Linux.jar")
    jar.merge("archive/jffi-sparc-SunOS.jar")
    jar.merge("archive/jffi-sparcv9-SunOS.jar")
    jar.merge("archive/jffi-ppc-AIX.jar")
    jar.merge("archive/jffi-ppc-Linux.jar")
    jar.merge(package(:jar, :classifier=>determine_cpu).to_s)
  end

  # Decide how we chain
  compile.enhance [generate_version]
  headers.enhance [compile]
  build.enhance [native_compilation]
  test.enhance [native_testlib]
  
  package(:jar).enhance [package(:jar, :classifier=>determine_cpu)]
end
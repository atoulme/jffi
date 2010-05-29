
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
  case determine_cpu
  when /FreeBSD/, /OpenBSD/, /AIX/ then
    return "gmake"
  when /SunOS/ then
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

  
  # Decide how we chain
  compile.enhance [generate_version]
  headers.enhance [compile]
  build.enhance [native_compilation]
  
end
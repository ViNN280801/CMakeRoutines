include("${MODULE_ROOT}/core/MsvcVcvarsConfig.cmake")
set(ENV{PROCESSOR_ARCHITEW6432} "")
set(ENV{PROCESSOR_ARCHITECTURE} "mips")
_msvc_vcvars_detect_host_arch(_r)

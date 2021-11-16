add_rules("mode.release", "mode.debug")
add_rules("platform.linux.bpf") -- we need this to build bpf programs
set_license("GPL-2.0")

option("system-libbpf",     {showmenu = true, default = false, description = "Use system-installed libbpf"})
option("require-bpftool",   {showmenu = true, default = false, description = "Require bpftool package"})
-- option("log-level",         {showmenu = true, default = 300, defines = "LOG_LEVEL", description = "Sets the logging level"})

add_requires("libelf", "zlib")

-- on linux
add_requires("llvm >=10.x")
set_toolchains("@llvm")
add_requires("linux-headers")

add_includedirs("./include/vmlinux")

-- we can run `xmake -f --require-bpftool=y` to pull
-- bpftool from xmake-repo repository
if has_config("require-bpftool") then
    add_requires("linux-tools", {configs = {bpftool = true}})
    add_packages("linux-tools")
else 
    before_build(function (target)
        os.addenv("PATH", path.join(os.scriptdir(), "tools"))
    end)
end

-- choose between the system-installed version of libbpf
-- or the one shipped with this repo
if has_config("system-libbpf") then
    add_requires("libbpf", {system = true})
else 
    target("libbpf")
        set_kind("static")
        set_basename("bpf")
        add_files("./libbpf/src/*.c")
        add_includedirs("./libbpf/include")
        add_includedirs("./libbpf/include/uapi", {public = true})
        add_includedirs("$(buildir)", {interface = true})
        add_configfiles("./libbpf/src/(*.h)", {prefixdir = "bpf"})
        add_packages("libelf", "zlib")
end

target("bpfstart")
    set_kind("binary")
    add_cflags("-g", "-Wall")
    add_defines("LOG_LEVEL=500")
    add_files("src/bpfstart*.c")
    add_includedirs("./include")
    add_packages("linux-tools", "linux-headers", "libbpf")
    if not has_config("system-libbpf") then
        add_deps("libbpf")
    end

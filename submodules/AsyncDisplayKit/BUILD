public_headers = glob([
  "Source/PublicHeaders/AsyncDisplayKit/*.h",
])

private_headers = glob([
  "Source/*.h",
], allow_empty=True)

objc_library(
    name = "AsyncDisplayKit",
    enable_modules = True,
    module_name = "AsyncDisplayKit",
    srcs = glob([
        "Source/**/*.m",
        "Source/**/*.mm",
    ], allow_empty=True) + private_headers,
    copts = [
        "-Wno-reorder-init-list",
        "-Wno-thread-safety-analysis",
        "-Werror",
    ],
    cxxopts = [
        "-Wno-thread-safety-analysis",
        "-Werror",
        "-std=c++17",
    ],
    hdrs = public_headers,
    defines = [
        "MINIMAL_ASDK",
    ],
    includes = [
      "Source/PublicHeaders",
    ],
    sdk_frameworks = [
      "Foundation",
      "UIKit",
      "QuartzCore",
      "CoreMedia",
      "CoreText",
      "CoreGraphics",
    ],
    visibility = [
        "//visibility:public",
    ],
)

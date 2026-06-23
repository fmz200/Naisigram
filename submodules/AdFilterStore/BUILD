load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "AdFilterStore",
    module_name = "AdFilterStore",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/Postbox",
        "//submodules/TelegramCore",
    ],
    visibility = [
        "//visibility:public",
    ],
)

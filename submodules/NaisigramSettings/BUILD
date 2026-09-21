load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "NaisigramSettings",
    module_name = "NaisigramSettings",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/Postbox",
        "//submodules/TelegramCore",
        "//submodules/AccountContext",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/Display",
        "//submodules/TelegramPresentationData",
        "//submodules/ItemListUI",
        "//submodules/PresentationDataUtils",
        "//submodules/AdFilterStore",
    ],
    visibility = [
        "//visibility:public",
    ],
)

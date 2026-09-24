// DictusApp/Views/LicensesView.swift
// Open-source license attributions for third-party dependencies.
import SwiftUI
import DictusCore

/// Displays license text for all open-source dependencies used in Dictus.
///
/// WHY a dedicated view:
/// Apple App Store guidelines require attribution for open-source licenses.
/// Placing them in Settings > A propos > Licences follows the standard iOS
/// convention (e.g., Settings > General > Legal & Regulatory).
///
/// All 7 entries are listed alphabetically: DeviceKit, Dictus, FluidAudio,
/// giellakbd-ios, Nemotron 3.5 ASR, VivaDicta, WhisperKit. FluidAudio uses Apache 2.0,
/// Nemotron 3.5 ASR uses OpenMDW-1.1; all others use MIT.
///
/// Nemotron 3.5 ASR is a MODEL, not code (#558): NVIDIA's weights, converted to Core ML by
/// FluidInference and downloaded by the user from HuggingFace. It is listed because its
/// licence asks for its agreement and NVIDIA's notices to travel with any distribution, and
/// because the brief asks for NVIDIA's attribution. The FluidAudio entry covers the SDK that
/// runs it and stays as it was.
///
/// "Dependency" is the loose sense here, and two entries are not packages at all.
/// giellakbd-ios is vendored source, and VivaDicta is a ported data table — the host-app
/// return catalogue in `KnownAppSchemes.swift`, copied with its annotations (#23). Both
/// are redistribution of MIT-licensed work, and MIT requires the copyright notice and the
/// licence text to travel with it, so both belong on this screen exactly like a linked
/// package. A provenance comment in the source file is honest but does not discharge the
/// condition.
struct LicensesView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                licenseBlock(
                    name: "DeviceKit",
                    author: "Dennis Weissmann",
                    url: "https://github.com/devicekit/DeviceKit",
                    license: mitLicense(copyright: "Copyright (c) 2015 Dennis Weissmann")
                )

                licenseBlock(
                    name: "Dictus",
                    author: "PIVI Solutions",
                    url: "https://github.com/getdictus/dictus-ios",
                    license: mitLicense(copyright: "Copyright (c) 2026 PIVI Solutions")
                )

                licenseBlock(
                    name: "FluidAudio",
                    author: "NVIDIA Corporation",
                    url: "https://github.com/FluidInference/FluidAudio",
                    license: apache2License(copyright: "Copyright NVIDIA Corporation")
                )

                licenseBlock(
                    name: "giellakbd-ios",
                    author: "UiT The Arctic University of Norway",
                    url: "https://github.com/divvun/giellakbd-ios",
                    license: mitLicense(copyright: "Copyright (c) 2019 UiT The Arctic University of Norway, Samediggi")
                )

                licenseBlock(
                    name: "Nemotron 3.5 ASR",
                    author: "NVIDIA Corporation",
                    url: "https://huggingface.co/nvidia/nemotron-3.5-asr-streaming-0.6b",
                    license: openMDWLicense(
                        notice: "Nemotron 3.5 ASR Streaming 0.6B, developed by NVIDIA Corporation. "
                            + "Core ML conversion by FluidInference "
                            + "(huggingface.co/FluidInference/Nemotron-3.5-ASR-Streaming-Multilingual-0.6b-CoreML)."
                    )
                )

                licenseBlock(
                    name: "VivaDicta",
                    author: "Anton Novoselov",
                    url: "https://github.com/n0an/VivaDicta",
                    license: mitLicense(copyright: "Copyright (c) 2026 Anton Novoselov")
                )

                licenseBlock(
                    name: "WhisperKit",
                    author: "Argmax, Inc.",
                    url: "https://github.com/argmaxinc/WhisperKit",
                    license: mitLicense(copyright: "Copyright (c) 2024 Argmax, Inc.")
                )

                Spacer(minLength: 32)
            }
            .padding()
        }
        .navigationTitle("Licenses")
    }

    // MARK: - Private

    private func licenseBlock(name: String, author: String, url: String, license: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(name)
                .font(.dictusSubheading)

            Text(author)
                .font(.dictusCaption)
                .foregroundColor(.secondary)

            if let link = URL(string: url) {
                Link(url, destination: link)
                    .font(.dictusCaption)
            }

            Text(license)
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(.secondary)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.tertiarySystemBackground))
                .cornerRadius(8)
        }
    }

    /// Standard MIT license text with customizable copyright line.
    private func mitLicense(copyright: String) -> String {
        """
        MIT License

        \(copyright)

        Permission is hereby granted, free of charge, to any person obtaining a copy \
        of this software and associated documentation files (the "Software"), to deal \
        in the Software without restriction, including without limitation the rights \
        to use, copy, modify, merge, publish, distribute, sublicense, and/or sell \
        copies of the Software, and to permit persons to whom the Software is \
        furnished to do so, subject to the following conditions:

        The above copyright notice and this permission notice shall be included in all \
        copies or substantial portions of the Software.

        THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR \
        IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, \
        FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE \
        AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER \
        LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, \
        OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE \
        SOFTWARE.
        """
    }

    /// The OpenMDW License Agreement, version 1.1, in full, under the model's notice of origin.
    ///
    /// WHY IN FULL, unlike the Apache short form below: the agreement is short, and its one
    /// condition on distribution is to retain "a copy of this agreement". Transcribed from
    /// openmdw.ai/license/1-1, read 2026-09-14. Legal text, so it stays in English, like the
    /// other licences on this screen.
    private func openMDWLicense(notice: String) -> String {
        """
        \(notice)

        OpenMDW License Agreement, version 1.1 (OpenMDW-1.1)

        By exercising rights granted to you under this agreement, you accept and agree to its terms.

        As used in this agreement, "Model Materials" means the materials provided to you under this \
        agreement, consisting of: (1) one or more machine learning models (including architecture and \
        parameters); and (2) all related artifacts (including associated data, documentation and \
        software) that are provided to you hereunder.

        Subject to your compliance with this agreement, permission is hereby granted, free of charge, \
        to deal in the Model Materials without restriction, including under all copyright, patent, \
        database, and trade secret rights included or embodied therein.

        If you distribute any portion of the Model Materials, you shall retain in your distribution \
        (1) a copy of this agreement, and (2) all copyright notices and other notices of origin \
        included in the Model Materials that are applicable to your distribution.

        If you file, maintain, or voluntarily participate in a lawsuit against any person or entity \
        asserting that the Model Materials directly or indirectly infringe any patent or copyright, \
        then all rights and grants made to you hereunder are terminated, unless that lawsuit was in \
        response to a corresponding lawsuit first brought against you.

        This agreement does not impose any restrictions or obligations with respect to any use, \
        modification, or sharing of any outputs generated by using the Model Materials.

        THE MODEL MATERIALS ARE PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, \
        INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR \
        PURPOSE, TITLE, NONINFRINGEMENT, ACCURACY, OR THE ABSENCE OF LATENT OR OTHER DEFECTS OR \
        ERRORS, WHETHER OR NOT DISCOVERABLE, ALL TO THE GREATEST EXTENT PERMISSIBLE UNDER APPLICABLE LAW.

        YOU ARE SOLELY RESPONSIBLE FOR (1) CLEARING RIGHTS OF OTHER PERSONS THAT MAY APPLY TO THE \
        MODEL MATERIALS OR ANY USE THEREOF, INCLUDING WITHOUT LIMITATION ANY PERSON'S COPYRIGHTS OR \
        OTHER RIGHTS INCLUDED OR EMBODIED IN THE MODEL MATERIALS; (2) OBTAINING ANY NECESSARY \
        CONSENTS, PERMISSIONS OR OTHER RIGHTS REQUIRED FOR ANY USE OF THE MODEL MATERIALS; OR \
        (3) PERFORMING ANY DUE DILIGENCE OR UNDERTAKING ANY OTHER INVESTIGATIONS INTO THE MODEL \
        MATERIALS OR ANYTHING INCORPORATED OR EMBODIED THEREIN.

        IN NO EVENT SHALL THE PROVIDERS OF THE MODEL MATERIALS BE LIABLE FOR ANY CLAIM, DAMAGES OR \
        OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF \
        OR IN CONNECTION WITH THE MODEL MATERIALS, THE USE THEREOF OR OTHER DEALINGS THEREIN.
        """
    }

    /// Short-form Apache 2.0 license notice (Section 4d compliant).
    /// Uses the standard boilerplate rather than the full 175-line text,
    /// which is the common practice for in-app attribution screens.
    private func apache2License(copyright: String) -> String {
        """
        Apache License, Version 2.0

        \(copyright)

        Licensed under the Apache License, Version 2.0 (the "License"); \
        you may not use this file except in compliance with the License. \
        You may obtain a copy of the License at

            http://www.apache.org/licenses/LICENSE-2.0

        Unless required by applicable law or agreed to in writing, software \
        distributed under the License is distributed on an "AS IS" BASIS, \
        WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. \
        See the License for the specific language governing permissions and \
        limitations under the License.
        """
    }
}

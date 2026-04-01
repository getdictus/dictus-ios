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
/// All 5 dependencies are listed alphabetically: DeviceKit, Dictus, FluidAudio,
/// giellakbd-ios, WhisperKit. FluidAudio uses Apache 2.0; all others use MIT.
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
                    name: "WhisperKit",
                    author: "Argmax, Inc.",
                    url: "https://github.com/argmaxinc/WhisperKit",
                    license: mitLicense(copyright: "Copyright (c) 2024 Argmax, Inc.")
                )

                Spacer(minLength: 32)
            }
            .padding()
        }
        .navigationTitle("Licences")
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

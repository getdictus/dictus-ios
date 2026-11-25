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
/// All 13 entries are listed alphabetically: DeviceKit, Dictus, DM Sans, FluidAudio,
/// giellakbd-ios, Google Books Ngram, Grammalecte, Hex, Nemotron 3.5 ASR, SCOWL, Unicode emoji
/// data and CLDR, VivaDicta, WhisperKit. FluidAudio uses Apache 2.0, Nemotron 3.5 ASR
/// OpenMDW-1.1, DM Sans the SIL Open Font License, Google Books Ngram CC BY 3.0, Grammalecte
/// MPL 2.0, SCOWL its own notice, the Unicode data the Unicode licence; all others use MIT.
///
/// Nemotron 3.5 ASR is a MODEL, not code (#558): NVIDIA's weights, converted to Core ML by
/// FluidInference and downloaded by the user from HuggingFace. It is listed because its
/// licence asks for its agreement and NVIDIA's notices to travel with any distribution, and
/// because the brief asks for NVIDIA's attribution. The FluidAudio entry covers the SDK that
/// runs it and stays as it was.
///
/// "Dependency" is the loose sense here, and three entries are not packages at all.
/// giellakbd-ios is vendored source, Hex is the return key's glyph-and-colour table in
/// `ReturnKeyStyle.swift` (#1023), and VivaDicta is a ported data table — the host-app
/// return catalogue in `KnownAppSchemes.swift`, copied with its annotations (#23). All
/// are redistribution of MIT-licensed work, and MIT requires the copyright notice and the
/// licence text to travel with it, so all three belong on this screen exactly like a linked
/// package. A provenance comment in the source file is honest but does not discharge the
/// condition.
///
/// Hex is listed for the keyboard's key geometry (`KeyPlaneGeometry`): no code is copied,
/// but the approach is Hex's (MIT), and the entry says so. Its entry also covers the spatial
/// decoder (#1011), the swipe decoder (#948), the emoji panel (#1027) and the delete swipe
/// (`DeleteWordSwipe`, #609), which are ported Hex code. The decoder adds three entries for where its
/// models come from: word and word-pair counts from Google Books Ngram (CC BY 3.0, which
/// asks for the attribution), and the word lists that filter them, SCOWL for English (its
/// notice asks to travel with the output) and Grammalecte's French dictionary (MPL 2.0,
/// whose notice and source location travel with a derived file). Hex's per-language
/// long-press accent lists are copied as data (`LongPressAccents`, #1042), under the same
/// MIT notice. Adaptive touch (#1014) is ported Hex code too, and the entry names it.
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
                    name: "DM Sans",
                    author: "The DM Sans Project Authors",
                    url: "https://github.com/googlefonts/dm-fonts",
                    license: dmSansLicense
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
                    name: "Google Books Ngram",
                    author: "Google",
                    url: "https://storage.googleapis.com/books/ngrams/books/datasetsv3.html",
                    license: Self.googleBooksNgramNotice
                )

                licenseBlock(
                    name: "Grammalecte (dictionnaire français)",
                    author: "Olivier R. and contributors",
                    url: "https://grammalecte.net",
                    license: Self.grammalecteNotice
                )

                licenseBlock(
                    name: "Hex",
                    author: "Christopher Langton",
                    url: "https://github.com/anomalyco/hex",
                    license: "The keyboard's key geometry (KeyPlaneGeometry) follows Hex's approach: "
                        + "Apple's key plane measured per iPhone size, and touch targets that tile the keyboard.\n\n"
                        + "The keyboard's emoji panel is Hex's, ported (#1027): its views, search, "
                        + "suggestions, shortcodes, skin tones and the builder of its emoji index.\n\n"
                        + "The spatial autocorrect decoder (SpatialDecoder) is ported from Hex's TypingDecoder.\n\n"
                        + "Adaptive touch, which learns where you tap each key (#1014), is ported from Hex's AdaptiveTouch.\n\n"
                        + "The swipe typing decoder (SwipeDecoder) is ported from Hex's SwipeDecoder; "
                        + "the swipe gesture, its trail and its text rules from Hex's SwipeTyping.\n\n"
                        + "The long-press accents of each keyboard language are Hex's lists (#1042), "
                        + "in the order Apple's keyboard shows them.\n\n"
                        + "Sliding left from the delete key to delete word by word, and back right to get "
                        + "the words back, is Hex's delete swipe, ported (#609).\n\n"
                        + mitLicense(copyright: "Copyright (c) 2026 Christopher Langton")
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
                    name: "SCOWL",
                    author: "Kevin Atkinson",
                    url: "http://wordlist.aspell.net",
                    license: Self.scowlNotice
                )

                licenseBlock(
                    name: "Unicode emoji data and CLDR",
                    author: "Unicode, Inc.",
                    url: "https://cldr.unicode.org",
                    license: "The emoji search index is built from Unicode's emoji-test.txt 18.0 and CLDR 49's "
                        + "emoji names and keywords in French, English, Spanish and German.\n\n"
                        + EmojiDataLicense.text
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

    /// Legal notices, so they stay in English like the other licences on this screen.
    private static let googleBooksNgramNotice = """
        The keyboard's spatial autocorrect models (fr.hextm, en.hextm) are built from the \
        Google Books Ngram Viewer data, version 3 (2020-02-17), by Google, licensed under \
        the Creative Commons Attribution 3.0 Unported License \
        (https://creativecommons.org/licenses/by/3.0/). Word and word-pair counts are \
        summed over 1980-2019 and kept only for words in the word lists below; the \
        English model is Hex's, the French one Dictus's, built with Hex's script.
        """

    private static let grammalecteNotice = """
        The French spatial autocorrect model (fr.hextm) keeps only the words the \
        "Classique" French dictionary of Grammalecte accepts (LibreOffice's fr_FR \
        dictionary, version 7.7). That dictionary is licensed under the Mozilla Public \
        License, version 2.0 (https://mozilla.org/MPL/2.0/). Its source form is \
        available at https://github.com/LibreOffice/dictionaries/tree/master/fr_FR. \
        The model file fr.hextm, derived from it, is offered under the same licence.
        """

    private static let scowlNotice = """
        The English spatial autocorrect model (en.hextm) keeps only the words of SCOWL \
        (Spell Checker Oriented Word Lists) and VarCon, sizes up to 70.

        Copyright 2000-2018 by Kevin Atkinson

        Permission to use, copy, modify, distribute and sell these word lists, the \
        associated scripts, the output created from the scripts, and its documentation \
        for any purpose is hereby granted without fee, provided that the above copyright \
        notice appears in all copies and that both that copyright notice and this \
        permission notice appear in supporting documentation. Kevin Atkinson makes no \
        representations about the suitability of this array for any purpose. It is \
        provided "as is" without express or implied warranty.

        SCOWL's inflections come from WordNet 1.6, Copyright 1997 by Princeton \
        University. All rights reserved. THIS SOFTWARE AND DATABASE IS PROVIDED "AS IS" \
        AND PRINCETON UNIVERSITY MAKES NO REPRESENTATIONS OR WARRANTIES, EXPRESS OR \
        IMPLIED.
        """

    /// The SIL Open Font License shipped with the DM Sans files (#913), read from the
    /// bundle so the text shown is the one distributed. OFL 1.1 asks for the license
    /// to accompany the font.
    private var dmSansLicense: String {
        guard let url = Bundle.main.url(forResource: "OFL", withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            return "Copyright 2014 The DM Sans Project Authors. SIL Open Font License, Version 1.1."
        }
        return text
    }

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

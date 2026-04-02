#!/usr/bin/env python3
"""
Curate French frequency dictionary from Lexique 3.83.

Downloads Lexique383.tsv, filters to top 40K words by combined frequency
(70% film subtitles + 30% books), adds SMS abbreviations and common proper nouns.
Outputs JSON {word: count} where higher count = more common.
"""

import json
import os
import sys
import urllib.request

LEXIQUE_URL = "http://www.lexique.org/databases/Lexique383/Lexique383.tsv"
TSV_FILE = "Lexique383.tsv"
OUTPUT = os.path.join(os.path.dirname(__file__), "..", "DictusKeyboard", "Resources", "fr_frequency.json")

# --- SMS / texting abbreviations with moderate frequency counts ---
SMS_ABBREVS = {
    "mdr": 500, "stp": 400, "bcp": 300, "jsp": 250, "slt": 200,
    "tkt": 200, "ptdr": 150, "pk": 150, "pcq": 150, "dsl": 150,
    "bjr": 100, "msg": 100, "rdv": 100, "tps": 100, "bsr": 80,
    "cc": 80, "cv": 80, "pb": 70, "svp": 70, "mtn": 60,
    "jpp": 60, "osef": 60, "tmtc": 50, "bg": 50, "ptn": 50,
    "oklm": 40, "tg": 40, "cad": 40, "jtm": 40, "jsuis": 40,
    "chui": 40, "bref": 40, "wsh": 35, "tqt": 35,
    "askip": 30, "deso": 30, "biz": 30, "att": 30,
    "omg": 25, "lol": 25, "btw": 25, "asap": 20, "fyi": 20,
    "imo": 20, "tlm": 20, "pq": 20, "nrv": 15, "sms": 15,
    "snap": 15, "insta": 15, "fb": 15,
}

# --- Common proper nouns (lowercased in dictionary, freq count 50) ---
PROPER_NOUNS = [
    # French cities
    "paris", "lyon", "marseille", "toulouse", "nice", "nantes", "strasbourg",
    "montpellier", "bordeaux", "lille", "rennes", "reims", "toulon", "grenoble",
    "dijon", "angers", "nimes", "clermont-ferrand", "rouen", "tours",
    "limoges", "amiens", "perpignan", "metz", "besancon", "orleans",
    "caen", "mulhouse", "brest", "avignon", "cannes", "antibes",
    "saint-etienne", "le havre", "aix-en-provence", "boulogne", "versailles",
    "nancy", "pau", "poitiers", "calais", "dunkerque", "valence",
    "ajaccio", "bastia", "colmar", "troyes", "chambery", "bayonne",

    # Countries
    "france", "espagne", "allemagne", "italie", "angleterre", "belgique",
    "suisse", "canada", "japon", "chine", "russie", "inde",
    "bresil", "maroc", "algerie", "tunisie", "senegal", "portugal",
    "grece", "turquie", "egypte", "mexique", "argentine", "colombie",
    "australie", "irlande", "ecosse", "pays-bas", "pologne", "roumanie",
    "hongrie", "autriche", "suede", "norvege", "danemark", "finlande",
    "ukraine", "israel", "liban", "iran", "irak", "syrie",
    "coree", "vietnam", "thailande", "indonesie", "pakistan", "afghanistan",
    "nigeria", "cameroun", "kenya", "afrique", "europe", "amerique", "asie",

    # Common first names (French)
    "pierre", "marie", "jean", "jacques", "louis", "philippe",
    "michel", "nicolas", "thomas", "antoine", "paul", "julie",
    "sophie", "claire", "anne", "catherine", "isabelle", "nathalie",
    "patrick", "christophe", "laurent", "stephane", "sylvie", "sandrine",
    "valerie", "veronique", "dominique", "pascal", "alain", "bernard",
    "christian", "daniel", "eric", "serge", "olivier", "thierry",
    "jerome", "bruno", "denis", "herve", "franck", "cedric",
    "arnaud", "romain", "alexandre", "maxime", "mathieu", "julien",
    "florian", "adrien", "hugo", "lucas", "leo", "gabriel",
    "raphael", "arthur", "louis", "emma", "jade", "louise",
    "alice", "chloe", "lina", "mila", "rose", "lea",
    "manon", "camille", "sarah", "laura", "marine", "emilie",
    "audrey", "lucie", "margaux", "charlotte", "mathilde", "clara",

    # International first names commonly used in France
    "mohamed", "ahmed", "karim", "youssef", "fatima", "aisha",
    "david", "william", "james", "john", "robert", "michael",
    "maria", "anna", "elena", "sofia", "luca", "marco",

    # Major world cities
    "londres", "berlin", "madrid", "rome", "bruxelles", "amsterdam",
    "lisbonne", "vienne", "prague", "varsovie", "moscou", "pekin",
    "tokyo", "new york", "washington", "los angeles", "chicago",
    "montreal", "toronto", "quebec", "geneve", "zurich", "berne",
    "barcelone", "milan", "florence", "venise", "naples", "athenes",
    "istanbul", "dubai", "le caire", "casablanca", "dakar", "abidjan",
    "tunis", "alger", "rabat", "beyrouth",

    # Geographic / cultural
    "seine", "loire", "rhone", "garonne", "rhin", "danube",
    "mediterranee", "atlantique", "pacifique", "arctique", "sahara",
    "alpes", "pyrenees", "normandie", "bretagne", "provence",
    "alsace", "bourgogne", "champagne", "corse", "aquitaine",

    # Brands / cultural references commonly typed
    "google", "apple", "facebook", "instagram", "tiktok", "youtube",
    "twitter", "whatsapp", "snapchat", "netflix", "spotify", "amazon",
    "uber", "airbnb", "wikipedia", "linkedin", "telegram", "discord",

    # Sports / cultural
    "psg", "olympique", "marseillaise", "sorbonne", "louvre", "eiffel",
]


def download_lexique():
    """Download Lexique 3.83 TSV if not already present."""
    if os.path.exists(TSV_FILE):
        print(f"[INFO] Using existing {TSV_FILE}")
        return
    print(f"[INFO] Downloading Lexique 3.83 from {LEXIQUE_URL}...")
    urllib.request.urlretrieve(LEXIQUE_URL, TSV_FILE)
    print(f"[INFO] Downloaded {os.path.getsize(TSV_FILE)} bytes")


def parse_lexique(tsv_path):
    """Parse Lexique TSV and return {word: combined_frequency} dict."""
    word_freq = {}

    with open(tsv_path, "r", encoding="utf-8") as f:
        header = f.readline().strip().split("\t")
        # Find column indices
        try:
            ortho_idx = header.index("ortho")
        except ValueError:
            # Try alternate column names
            for i, col in enumerate(header):
                if col.strip().lower() in ("ortho", "1_ortho"):
                    ortho_idx = i
                    break
            else:
                print(f"[ERROR] Could not find 'ortho' column. Headers: {header[:10]}")
                sys.exit(1)

        # Find frequency columns
        freqfilms_idx = None
        freqlivres_idx = None
        for i, col in enumerate(header):
            col_clean = col.strip().lower()
            if col_clean in ("freqfilms2", "7_freqfilms2"):
                freqfilms_idx = i
            elif col_clean in ("freqlivres", "6_freqlivres"):
                freqlivres_idx = i

        if freqfilms_idx is None or freqlivres_idx is None:
            # Try numbered columns
            for i, col in enumerate(header):
                if "freqfilm" in col.lower():
                    freqfilms_idx = i
                elif "freqlivr" in col.lower():
                    freqlivres_idx = i

        if freqfilms_idx is None or freqlivres_idx is None:
            print(f"[ERROR] Could not find frequency columns. Headers: {header[:15]}")
            sys.exit(1)

        print(f"[INFO] Columns: ortho={ortho_idx}, freqfilms2={freqfilms_idx}, freqlivres={freqlivres_idx}")

        for line in f:
            parts = line.strip().split("\t")
            if len(parts) <= max(ortho_idx, freqfilms_idx, freqlivres_idx):
                continue

            word = parts[ortho_idx].strip().lower()
            if not word:
                continue

            try:
                ff = float(parts[freqfilms_idx].replace(",", "."))
            except (ValueError, IndexError):
                ff = 0.0
            try:
                fl = float(parts[freqlivres_idx].replace(",", "."))
            except (ValueError, IndexError):
                fl = 0.0

            # Combined frequency: 70% films, 30% books
            freq = ff * 0.7 + fl * 0.3

            # Keep highest frequency for each word (Lexique has multiple POS entries)
            if freq > word_freq.get(word, 0):
                word_freq[word] = freq

    return word_freq


def main():
    download_lexique()
    print("[INFO] Parsing Lexique 3.83...")
    word_freq = parse_lexique(TSV_FILE)
    print(f"[INFO] Parsed {len(word_freq)} unique words from Lexique")

    # Filter: freq > 0, sort descending
    filtered = {w: f for w, f in word_freq.items() if f > 0}
    sorted_words = sorted(filtered.items(), key=lambda x: -x[1])

    # Take top 40,000
    top_words = sorted_words[:40000]

    # Convert to {word: count} where count = max(1, int(freq * 100))
    freq_dict = {}
    for word, freq in top_words:
        count = max(1, int(freq * 100))
        freq_dict[word] = count

    print(f"[INFO] Top words: {len(freq_dict)} entries")

    # Add SMS abbreviations (don't overwrite existing higher-frequency words)
    added_sms = 0
    for word, count in SMS_ABBREVS.items():
        if word not in freq_dict:
            freq_dict[word] = count
            added_sms += 1
    print(f"[INFO] Added {added_sms} SMS abbreviations")

    # Add proper nouns (don't overwrite existing higher-frequency words)
    added_proper = 0
    for word in PROPER_NOUNS:
        word = word.strip().lower()
        if word and word not in freq_dict:
            freq_dict[word] = 50
            added_proper += 1
    print(f"[INFO] Added {added_proper} proper nouns")

    # Output
    output_path = os.path.abspath(OUTPUT)
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(freq_dict, f, ensure_ascii=False, separators=(",", ":"))

    print(f"[DONE] Wrote {len(freq_dict)} entries to {output_path}")

    # Cleanup downloaded file
    if os.path.exists(TSV_FILE):
        os.remove(TSV_FILE)
        print(f"[INFO] Cleaned up {TSV_FILE}")


if __name__ == "__main__":
    main()

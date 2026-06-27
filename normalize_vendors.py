#!/usr/bin/env python3
"""
Normalize MAC OUI vendor names for better compression.
Input-file-format: "AABBCC company name" on each line (uppercase mac-vendor part + naming)
Usage: python3 normalize_vendors.py raw.txt [output.txt]
"""

import re
import sys
import unicodedata

# ---------------------------------------------------------------------------
# Step 1: Base normalizations
# ---------------------------------------------------------------------------


def base_normalize(name):
    name = name.upper()
    name = unicodedata.normalize("NFKD", name).encode("ascii", "ignore").decode("ascii")
    name = name.replace("\uff08", "(").replace("\uff09", ")")
    name = name.replace("\uff0c", ",").replace("\uff0e", ".")
    name = re.sub(r"[\u4e00-\u9fff]+", "", name)
    name = re.sub(r"[\s\xa0]+", " ", name).strip()
    return name


# ---------------------------------------------------------------------------
# Step 2: Entity suffix normalisation (order matters – specific first)
# ---------------------------------------------------------------------------

ENTITY_PATTERNS = [
    (re.compile(r"\bCO\b[.;,]*\s*(?:LTD|LIMITED)\s*\.*\s*$"), "CO.,LTD"),
    (re.compile(r"\b(?:INCORPORATED|INC)\.*\s*$"), "INC"),
    (
        re.compile(r"\b(?:CORPORATION|CORP)\.?,?\s*(?:LTD|LIMITED)\s*\.*\s*$"),
        "CORP.,LTD",
    ),
    (re.compile(r"\b(?:CORPORATION|CORP)\.*\s*$"), "CORP"),
    (re.compile(r"\bLIMITED\s*$"), "LTD"),
    (re.compile(r"\bLTD\.*\s*$"), "LTD"),
    (re.compile(r"\bCOMPANY\s*$"), "CO"),
    (re.compile(r"\bLLC\.*\s*$"), "LLC"),
    (re.compile(r"\bLTDA\.*\s*$"), "LTDA"),
    (re.compile(r"\bPTE\.?\s+LTD\.*\s*$"), "PTE LTD"),
    (re.compile(r"\bSDN\.?\s+BHD\.*\s*$"), "SDN BHD"),
    (re.compile(r"\bPLC\.*\s*$"), "PLC"),
    (re.compile(r"\bCO\b[.;,]*\s+(?:LTD|LIMITED)\s*\.*\s*$"), "CO.,LTD"),
]


def normalize_entity(name):
    for _ in range(2):
        for pat, repl in ENTITY_PATTERNS:
            name = pat.sub(repl, name)
    return name


# ---------------------------------------------------------------------------
# Step 3: Common-word abbreviations (longest first to avoid partial matches)
# ---------------------------------------------------------------------------

WORD_ABBREVIATIONS = [
    (re.compile(r"\bMICROELECTRONICS\b"), "MICROELEC"),
    (re.compile(r"\bTELECOMMUNICATIONS\b"), "TELECOM"),
    (re.compile(r"\bTELECOMMUNICATION\b"), "TELECOM"),
    (re.compile(r"\bTECHNOLOGIES\b"), "TECH"),
    (re.compile(r"\bTECHNOLOGY\b"), "TECH"),
    (re.compile(r"\bELECTRONICS\b"), "ELEC"),
    (re.compile(r"\bELECTRONIC\b"), "ELEC"),
    (re.compile(r"\bCOMMUNICATIONS\b"), "COMM"),
    (re.compile(r"\bCOMMUNICATION\b"), "COMM"),
    (re.compile(r"\bMANUFACTURING\b"), "MFG"),
    (re.compile(r"\bINTERNATIONAL\b"), "INTL"),
    (re.compile(r"\bENTERPRISE\b"), "ENT"),
    (re.compile(r"\bINFORMATION\b"), "INFO"),
    (re.compile(r"\bSOLUTIONS\b"), "SOLN"),
    (re.compile(r"\bSOLUTION\b"), "SOLN"),
    (re.compile(r"\bSYSTEMS\b"), "SYS"),
    (re.compile(r"\bSYSTEM\b"), "SYS"),
    (re.compile(r"\bNETWORKS\b"), "NET"),
    (re.compile(r"\bNETWORKING\b"), "NET"),
    (re.compile(r"\bNETWORK\b"), "NET"),
    (re.compile(r"\bEQUIPMENT\b"), "EQPT"),
    (re.compile(r"\bDEVELOPMENT\b"), "DEV"),
    (re.compile(r"\bINTELLIGENT\b"), "IGENT"),
    (re.compile(r"\bAUTOMATION\b"), "AUTO"),
    (re.compile(r"\bDIGITAL\b"), "DIG"),
    (re.compile(r"\bSEMICONDUCTOR\b"), "SEMI"),
    (re.compile(r"\bDISTRIBUTION\b"), "DIST"),
    (re.compile(r"\bDISTRIBUTOR\b"), "DIST"),
    (re.compile(r"\bSERVICES\b"), "SVC"),
    (re.compile(r"\bPRODUCTS\b"), "PROD"),
    (re.compile(r"\bPRODUCT\b"), "PROD"),
    (re.compile(r"\bINDUSTRIAL\b"), "IND"),
    (re.compile(r"\bACCESSORIES\b"), "ACC"),
    (re.compile(r"\bCONSUMER\b"), "CONS"),
    (re.compile(r"\bDESIGN\b"), "DSN"),
    (re.compile(r"\bWIRELESS\b"), "WRLS"),
    (re.compile(r"\bSOFTWARE\b"), "SW"),
    (re.compile(r"\bHARDWARE\b"), "HW"),
    (re.compile(r"\bINTEGRATION\b"), "INTEG"),
    (re.compile(r"\bINTEGRATED\b"), "INTEG"),
]


def abbreviate_words(name):
    for pat, repl in WORD_ABBREVIATIONS:
        name = pat.sub(repl, name)
    return name


# ---------------------------------------------------------------------------
# Step 5: Vendor-merging rules (first match wins)
# ---------------------------------------------------------------------------

MERGE_RULES = [
    (re.compile(r"^3COM\b.*"), "3COM"),
    (re.compile(r"^ABB\b.*"), "ABB LTD"),
    (re.compile(r"^ALCATEL\b.*"), "ALCATEL-LUCENT"),
    (re.compile(r"^AMAZON\b.*"), "AMAZON TECH INC"),
    (re.compile(r"^AVAGO\b.*"), "BROADCOM"),
    (re.compile(r"^AVM AUDIOVISUELLES\b.*"), "AVM GERMANY"),
    (re.compile(r"^AVM GMBH\b.*"), "AVM GERMANY"),
    (re.compile(r"^AVM$"), "AVM GERMANY"),
    (re.compile(r"^BEIJING XIAOMI\b.*"), "XIAOMI COMM CO.,LTD"),
    (re.compile(r"^BLINK BY AMAZON\b.*"), "AMAZON TECH INC"),
    (re.compile(r"^BOSCH\b.*"), "BOSCH GMBH"),
    (re.compile(r"^BROADCOM\b.*"), "BROADCOM"),
    (re.compile(r"^CANON\b.*"), "CANON INC"),
    (re.compile(r"^CISCO\b.*"), "CISCO SYSTEMS INC"),
    (re.compile(r"^COMMSCOPE\b.*"), "COMMSCOPE"),
    (re.compile(r"^DELL\b(?:[\s,].*)?$"), "DELL INC"),
    (re.compile(r"^EATON\b.*"), "EATON CORP"),
    (re.compile(r"^EMERSON\b.*"), "EMERSON CORP"),
    (re.compile(r"^ERICSSONLG\b.*"), "ERICSSON"),
    (re.compile(r"^ERICSSON\b.*"), "ERICSSON"),
    (re.compile(r"^FOXCONN\b.*"), "FOXCONN"),
    (re.compile(r"^FUJITSU\b.*"), "FUJITSU LTD"),
    (re.compile(r"^HEWLETT[\s-]PACKARD\b.*"), "HP INC"),
    (re.compile(r"^HITACHI\b.*"), "HITACHI LTD"),
    (re.compile(r"^HON HAI\b.*"), "FOXCONN"),
    (re.compile(r"^HONEYWELL\b.*"), "HONEYWELL INTL INC"),
    (re.compile(r"^HONOR\b.*"), "HONOR DEVICE CO.,LTD"),
    (re.compile(r"^HP\b.*"), "HP INC"),
    (re.compile(r"^HUAWEI\b.*"), "HUAWEI TECH CO.,LTD"),
    (re.compile(r"^IBM\b.*"), "IBM CORP"),
    (re.compile(r"^INTEL\s+CORPORATE$"), "INTEL CORP"),
    (re.compile(r"^INTEL\s+CORPORATION$"), "INTEL CORP"),
    (re.compile(r"^KYOCERA\b.*"), "KYOCERA CORP"),
    (re.compile(r"^LENOVO\b.*"), "LENOVO CORP"),
    (re.compile(r"^LG\b.*"), "LG CORP"),
    (re.compile(r"^LUCENT\b.*"), "ALCATEL-LUCENT"),
    (re.compile(r"^MICROSOFT\b.*"), "MICROSOFT CORP"),
    (re.compile(r"^MITSUBISHI\b.*"), "MITSUBISHI CORP"),
    (re.compile(r"^MOTOROLA\b.*\(WUHAN\).*"), "MOTOROLA MOBILITY LLC"),
    (re.compile(r"^MOTOROLA MOBILITY\b.*"), "MOTOROLA MOBILITY LLC"),
    (re.compile(r"^MOTOROLA SOLUTIONS\b.*"), "MOTOROLA SOLUTIONS INC"),
    (re.compile(r"^MOTOROLA\b.*"), "MOTOROLA INC"),
    (re.compile(r"^NEC\b.*"), "NEC CORP"),
    (re.compile(r"^NOKIA\b.*"), "NOKIA"),
    (re.compile(r"^PANASONIC\b.*"), "PANASONIC CORP"),
    (re.compile(r"^PHILIPS\b.*"), "PHILIPS"),
    (re.compile(r"^PRIVATE$"), "PRIVATE"),
    (re.compile(r"^RICOH\b.*"), "RICOH CO.,LTD"),
    (re.compile(r"^ROCKWELL\b.*"), "ROCKWELL AUTO"),
    (re.compile(r"^SAMSUNG\b.*"), "SAMSUNG ELEC CO.,LTD"),
    (re.compile(r"^SCHNEIDER\b.*"), "SCHNEIDER ELEC"),
    (re.compile(r"^SIEMENS\b.*"), "SIEMENS AG"),
    (re.compile(r"^SONY\b.*"), "SONY CORP"),
    (re.compile(r"^TOSHIBA\b.*"), "TOSHIBA CORP"),
    (re.compile(r"^TP[\s-]?LINK\b.*"), "TP-LINK TECH CO.,LTD"),
    (re.compile(r"^WIRELESS\s+DATA\s+GROUP\b.*"), "MOTOROLA INC"),
    (re.compile(r"^XIAOMI\b.*"), "XIAOMI COMM CO.,LTD"),
]


def merge_vendor(name):
    for pat, repl in MERGE_RULES:
        if pat.match(name):
            return repl
    return name


# ---------------------------------------------------------------------------
# Step 6: Strip entity suffixes (applied AFTER merge to avoid needed
#         suffix-less merge-target updates)
# ---------------------------------------------------------------------------

SUFFIX_PATTERNS = [
    (
        re.compile(
            r",?\s*(?:GMBH|G\.?M\.?B\.?H\.?)\s*(?:&|UND|AND)\s*(?:CO\.?|COMPANY)\s*(?:KG|KOMMANDITGESELLSCHAFT)\.?\s*$"
        ),
        "",
    ),
    (re.compile(r",?\s*CO[.;,]*\s*(?:LTD|LIMITED)\.?\s*$"), ""),
    (re.compile(r",?\s*(?:CORPORATION|CORP)[.;,]*\s*(?:LTD|LIMITED)\.?\s*$"), ""),
    (re.compile(r",?\s*PTE\.?\s+LTD\.?\s*$"), ""),
    (re.compile(r",?\s*SDN\.?\s+BHD\.?\s*$"), ""),
    (re.compile(r",?\s*PTY\.?\s+LTD\.?\s*$"), ""),
    (re.compile(r",?\s*(?:INCORPORATED|INC)\.?\s*$"), ""),
    (re.compile(r",?\s*(?:CORPORATION|CORP)\.?\s*$"), ""),
    (re.compile(r",?\s*(?:LIMITED|LTD)\.?\s*$"), ""),
    (re.compile(r",?\s+COMPANY\s*$"), ""),
    (re.compile(r",?\s+CO\.?\s*$"), ""),
    (re.compile(r",?\s+GMBH\.?\s*$"), ""),
    (re.compile(r",?\s+LLC\.?\s*$"), ""),
    (re.compile(r",?\s+PLC\.?\s*$"), ""),
    (re.compile(r",?\s+LTDA\.?\s*$"), ""),
    (re.compile(r",?\s+AG\.?\s*$"), ""),
    (re.compile(r",?\s+AB\.?\s*$"), ""),
    (re.compile(r",?\s+AS\s*$"), ""),
    (re.compile(r",?\s+A/S\.?\s*$"), ""),
    (re.compile(r",?\s+OY\.?\s*$"), ""),
    (re.compile(r",?\s+KG\.?\s*$"), ""),
    (re.compile(r",?\s+BV\.?\s*$"), ""),
    (re.compile(r",?\s+NV\.?\s*$"), ""),
    (re.compile(r",?\s+SA\.?\s*$"), ""),
    (re.compile(r",?\s+SAS\.?\s*$"), ""),
    (re.compile(r",?\s+SPA\.?\s*$"), ""),
    (re.compile(r",?\s+SRL\.?\s*$"), ""),
    (re.compile(r",?\s+KK\.?\s*$"), ""),
]


def strip_suffixes(name):
    for _ in range(3):
        for pat, _ in SUFFIX_PATTERNS:
            name = pat.sub("", name)
    return name


# ---------------------------------------------------------------------------
# Pipeline
# ---------------------------------------------------------------------------


def normalize(name):
    name = base_normalize(name)
    if not name:
        return "UNKNOWN"
    name = normalize_entity(name)
    name = abbreviate_words(name)
    name = merge_vendor(name)  # merge first (canonical forms still have suffixes)
    name = re.sub(r"\.+", "", name)  # remove ALL periods
    name = re.sub(r"\([^)]*\)", "", name)  # remove balanced parentheses + content
    name = re.sub(r"\([^)]*$", "", name)  # remove unmatched opening paren to end
    name = re.sub(r"[,;.:\s]+$", "", name)  # trailing punctuation BEFORE suffix strip
    name = strip_suffixes(name)  # then strip entity designations
    name = re.sub(r"\s*\(\s*\)", "", name)  # remove any empty paren leftovers
    name = re.sub(r"[-&,/+!;?@:*\'`]", "", name)  # remove special chars
    name = re.sub(r"\s+", " ", name).strip()
    name = re.sub(r"[,;.:\s]+$", "", name)  # trailing punctuation cleanup
    name = re.sub(r"\s+", " ", name).strip()
    if not name:
        return "UNKNOWN"
    return name


def process(inpath, outpath):
    count = 0
    with open(inpath, "r", encoding="utf-8") as fin, open(
        outpath, "w", encoding="utf-8", newline="\n"
    ) as fout:
        for line in fin:
            line = line.rstrip("\r\n")
            if len(line) < 8:
                continue
            mac = line[:6]
            vendor = line[7:]
            if not vendor.strip():
                continue
            norm = normalize(vendor)
            fout.write(f"{mac} {norm}\n")
            count += 1
    return count


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <input> [output]")
        sys.exit(1)

    src = sys.argv[1]
    dst = sys.argv[2] if len(sys.argv) > 2 else src

    n = process(src, dst)
    print(f"Normalized {n} entries -> {dst}")

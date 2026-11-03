from dataclasses import dataclass, field
from typing import Optional
import matplotlib.pyplot as plt
import numpy as np
import glob
import os
import re

# --- Data classes ---

@dataclass
class WSCards:
    type: str
    subtype: str
    epoch: int
    state: int
    mode: int
    sampling_rate: int
    sample_size: int
    gain: float
    file_size: float
    total: int
    free: int
    crc: str

@dataclass
class SDF:
    type: str
    number_of_cards: str
    card1_state: int
    card1_total_storage: int
    card1_free_storage: int
    card2_state: int
    card2_total_storage: int
    card2_free_storage: int
    crc: str

@dataclass
class DiveDataset:
    dive_number: int
    ws_cards: list[WSCards] = field(default_factory=list)
    sdf: list[SDF]          = field(default_factory=list)


# --- Parsing ---

def split_checksum(last_field: str) -> tuple[str, str]:
    if "*" in last_field:
        val, chk = last_field.split("*", 1)
        return val, chk
    return last_field, ""

def parse_ws_cards(parts: list[str]) -> WSCards:
    parts[-1], checksum = split_checksum(parts[-1])
    return WSCards(
        type          = parts[0],
        subtype       = parts[1],
        epoch         = int(parts[2]),
        state         = int(parts[3]),
        mode          = int(parts[4]),
        sampling_rate = int(parts[5]),
        sample_size   = int(parts[6]),
        gain          = float(parts[7]),
        file_size     = float(parts[8]),
        total         = int(parts[9]),
        free          = int(parts[10]),
        crc           = checksum,
    )

def parse_sdf(parts: list[str]) -> SDF:
    parts[-1], checksum = split_checksum(parts[-1])
    return SDF(
        type                = parts[0],
        number_of_cards     = parts[1],
        card1_state         = int(parts[2]),
        card1_total_storage = int(parts[3]),
        card1_free_storage  = int(parts[4]),
        card2_state         = int(parts[5]),
        card2_total_storage = int(parts[6]),
        card2_free_storage  = int(parts[7]),
        crc                 = checksum,
    )

PARSERS = {
    "$WS_CARDS": parse_ws_cards,
    "$SDF":      parse_sdf,
}

def parse_dive_number(lines: list[str]) -> int:
    """Extract dive number from the log file header."""
    for line in lines:
        match = re.match(r'^dive:\s*(\d+)', line)
        if match:
            return int(match.group(1))
    return -1  # unknown dive

def parse_logfile(filepath: str) -> DiveDataset:
    with open(filepath, "r") as f:
        lines = f.readlines()

    dive_number = parse_dive_number(lines)
    dataset = DiveDataset(dive_number=dive_number)

    for line in lines:
        line = line.strip()
        if not line:
            continue
        parts = line.split(",")
        msg_type = parts[0]
        parser = PARSERS.get(msg_type)
        if parser is None:
            continue  # silently skip unknown lines
        try:
            record = parser(parts)
            if msg_type == "$WS_CARDS":
                dataset.ws_cards.append(record)
            elif msg_type == "$SDF":
                dataset.sdf.append(record)
        except (ValueError, IndexError) as e:
            print(f"Skipping malformed line in dive {dive_number}: {line!r} ({e})")

    return dataset

def parse_all_logfiles(log_dir: str, pattern: str = "*.log") -> list[DiveDataset]:
    """Parse all logfiles in a directory and return sorted by dive number."""
    files = glob.glob(os.path.join(log_dir, pattern))
    if not files:
        print(f"No files found matching {os.path.join(log_dir, pattern)}")
        return []

    dives = [parse_logfile(f) for f in files]
    dives.sort(key=lambda d: d.dive_number)
    print(f"Parsed {len(dives)} logfiles: dives {[d.dive_number for d in dives]}")
    return dives


# --- Plotting ---

def plot_card_space(dives: list[DiveDataset], save_path: str = None) -> None:
    """Plot card1 and card2 free/used storage across dives."""
    sdf_dives = [(d.dive_number, d.sdf[-1]) for d in dives if d.sdf]
    if not sdf_dives:
        print("No SDF data to plot.")
        return

    dive_nums   = [d[0]                      for d in sdf_dives]
    card1_total = [d[1].card1_total_storage   for d in sdf_dives]
    card1_free  = [d[1].card1_free_storage    for d in sdf_dives]
    card1_used  = [t - f for t, f in zip(card1_total, card1_free)]
    card2_total = [d[1].card2_total_storage   for d in sdf_dives]
    card2_free  = [d[1].card2_free_storage    for d in sdf_dives]
    card2_used  = [t - f for t, f in zip(card2_total, card2_free)]

    # Convert to GB
    to_gb = lambda vals: [v / (1024**3) for v in vals]
    c1_total_gb = to_gb(card1_total)
    c1_free_gb  = to_gb(card1_free)
    c1_used_gb  = to_gb(card1_used)
    c2_total_gb = to_gb(card2_total)
    c2_free_gb  = to_gb(card2_free)
    c2_used_gb  = to_gb(card2_used)

    fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(12, 7), sharex=True)

    ax1.stackplot(dive_nums, c1_used_gb, c1_free_gb,
                  labels=["Used", "Free"], colors=["#e07b7b", "#7bc8e0"])
    ax1.set_ylabel("Storage (GB)")
    ax1.set_title("WISPR Card 1 Storage")
    ax1.legend(loc="upper left")
    ax1.set_ylim(0, max(c1_total_gb) * 1.1 if c1_total_gb else 1)

    ax2.stackplot(dive_nums, c2_used_gb, c2_free_gb,
                  labels=["Used", "Free"], colors=["#e07b7b", "#7bc8e0"])
    ax2.set_ylabel("Storage (GB)")
    ax2.set_title("WISPR Card 2 Storage")
    ax2.set_xlabel("Dive Number")
    ax2.legend(loc="upper left")
    ax2.set_ylim(0, max(c2_total_gb) * 1.1 if c2_total_gb else 1)

    plt.tight_layout()
    plt.savefig(save_path, dpi=300)


# --- Usage ---
LOG_DIR   = rf"C:\Users\marqjace\data\seaglider\sg266\2026_11_02_wispr"
SAVE_PATH = os.path.join(LOG_DIR, "wispr_card_space.png")

dives = parse_all_logfiles(LOG_DIR)
plot_card_space(dives, save_path=SAVE_PATH)
import argparse
import re
from pathlib import Path

import matplotlib.pyplot as plt

RATE_PATTERN = re.compile(r"average rate:\s*([\d.]+)")
STATS_PATTERN = re.compile(
    r"min:\s*([\d.]+)s\s+max:\s*([\d.]+)s\s+std dev:\s*([\d.]+)s\s+window:\s*(\d+)"
)


def parse_hz_log(path):
    samples = []
    average_rate = None
    for line in path.read_text().splitlines():
        rate_match = RATE_PATTERN.search(line)
        if rate_match:
            average_rate = float(rate_match.group(1))
            continue
        stats_match = STATS_PATTERN.search(line)
        if stats_match and average_rate is not None:
            min_interval, max_interval, std_dev, window = stats_match.groups()
            samples.append(
                {
                    "average_rate": average_rate,
                    "min_interval": float(min_interval),
                    "max_interval": float(max_interval),
                    "std_dev": float(std_dev),
                    "window": int(window),
                }
            )
            average_rate = None
    return samples


def plot_samples(samples, title, output_path):
    windows = [sample["window"] for sample in samples]
    figure, axes = plt.subplots(3, 1, figsize=(10, 9), sharex=True)

    axes[0].plot(windows, [sample["average_rate"] for sample in samples])
    axes[0].set_ylabel("Average rate [Hz]")

    axes[1].plot(windows, [sample["std_dev"] for sample in samples])
    axes[1].set_ylabel("Std dev [s]")

    axes[2].plot(
        windows, [sample["max_interval"] for sample in samples], label="max interval"
    )
    axes[2].plot(
        windows, [sample["min_interval"] for sample in samples], label="min interval"
    )
    axes[2].set_ylabel("Interval between messages [s]")
    axes[2].set_xlabel("Messages received")
    axes[2].legend()

    axes[0].set_title(title)
    for axis in axes:
        axis.grid(True, alpha=0.3)
    figure.tight_layout()
    figure.savefig(output_path, dpi=150)


def main():
    parser = argparse.ArgumentParser(
        description="Plot the output of `ros2 topic hz` saved to a file."
    )
    parser.add_argument(
        "log_file", type=Path, help="file with saved `ros2 topic hz` output"
    )
    parser.add_argument(
        "--output", type=Path, help="output image (defaults to <log_file>.png)"
    )
    parser.add_argument("--show", action="store_true", help="open the plot in a window")
    args = parser.parse_args()

    samples = parse_hz_log(args.log_file)
    if not samples:
        raise SystemExit(f"No `ros2 topic hz` samples found in {args.log_file}")

    output_path = args.output or args.log_file.with_suffix(".png")
    plot_samples(samples, f"ros2 topic hz: {args.log_file.name}", output_path)

    print(f"Saved plot to {output_path}")
    if args.show:
        plt.show()


if __name__ == "__main__":
    main()

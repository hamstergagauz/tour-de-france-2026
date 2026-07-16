import argparse
from pathlib import Path

import numpy as np
from PIL import Image


def replace_background(path: Path) -> None:
    image = Image.open(path).convert("RGB")
    pixels = np.asarray(image, dtype=np.float32)

    corner_samples = np.concatenate(
        (
            pixels[:12, :12].reshape(-1, 3),
            pixels[:12, -12:].reshape(-1, 3),
            pixels[-12:, :12].reshape(-1, 3),
            pixels[-12:, -12:].reshape(-1, 3),
        )
    )
    key = np.median(corner_samples, axis=0)
    distance = np.linalg.norm(pixels - key, axis=2)

    red, green, blue = pixels[:, :, 0], pixels[:, :, 1], pixels[:, :, 2]
    green_like = (green > red * 1.22) & (green > blue * 1.08)
    alpha = np.clip((distance - 24.0) / 52.0, 0.0, 1.0)
    alpha = np.where(green_like, alpha, 1.0)[:, :, None]

    white = np.full_like(pixels, 255.0)
    result = pixels * alpha + white * (1.0 - alpha)
    Image.fromarray(np.uint8(np.clip(result, 0, 255)), "RGB").save(
        path, format="JPEG", quality=94, subsampling=0, optimize=True
    )


def main() -> None:
    parser = argparse.ArgumentParser(description="Replace flat green rider-photo backgrounds with white.")
    parser.add_argument("--directory", type=Path, required=True)
    args = parser.parse_args()

    photos = sorted(args.directory.glob("*.jpg"))
    if not photos:
        raise SystemExit(f"No JPG files found in {args.directory}")

    for photo in photos:
        replace_background(photo)
    print(f"Replaced backgrounds in {len(photos)} rider photos.")


if __name__ == "__main__":
    main()

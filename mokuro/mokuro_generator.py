from json import JSONDecodeError
from pathlib import Path

from loguru import logger
from tqdm import tqdm

from mokuro import __version__
from mokuro.manga_page_ocr import MangaPageOcr
from mokuro.utils import dump_json, load_json
from mokuro.volume import Volume


class Block:
    box: list[int]
    vertical: bool
    font_size: int
    lines_coords: list[list[list[float]]]
    lines: list[str]

    def __init__(
            self, box: list[int], vertical: bool, font_size: int, lines_coords: list[list[list[float]]],
            lines: list[str]
    ):
        self.box = box
        self.vertical = vertical
        self.font_size = font_size
        self.lines_coords = lines_coords
        self.lines = lines

    @classmethod
    def from_dict(cls, data: dict) -> "Block":
        return cls(
            box=data["box"],
            vertical=data["vertical"],
            font_size=data["font_size"],
            lines_coords=data["lines_coords"],
            lines=data["lines"],
        )


class Page:
    version: str
    img_width: int
    img_height: int
    blocks: list[Block]
    img_path: str

    def __init__(self, version: str, img_width: int, img_height: int, blocks: list[Block], img_path: str):
        self.version = version
        self.img_width = img_width
        self.img_height = img_height
        self.blocks = blocks
        self.img_path = img_path

    @classmethod
    def from_dict(cls, data: dict) -> "Page":
        return cls(
            version=data["version"],
            img_width=data["img_width"],
            img_height=data["img_height"],
            blocks=[Block(**block) for block in data["blocks"]],
            img_path=data["img_path"],
        )


class MokuroGenerator:
    def __init__(
            self, pretrained_model_name_or_path="kha-white/manga-ocr-base", force_cpu=False, disable_ocr=False, **kwargs
    ):
        self.pretrained_model_name_or_path = pretrained_model_name_or_path
        self.force_cpu = force_cpu
        self.disable_ocr = disable_ocr
        self.kwargs = kwargs
        self.mpocr: MangaPageOcr | None = None

    def init_models(self):
        if self.mpocr is None:
            self.mpocr = MangaPageOcr(
                self.pretrained_model_name_or_path,
                force_cpu=self.force_cpu,
                disable_ocr=self.disable_ocr,
                **self.kwargs,
            )

    def process_volume(self, volume: Volume, ignore_errors=False, no_cache: bool = False):
        volume.path_ocr_cache.mkdir(parents=True, exist_ok=True)

        if volume.mokuro_data is not None:
            pages: list[Page] = [Page.from_dict(page) for page in volume.mokuro_data["pages"]]
            for page in pages:
                json_path: Path = (volume.path_ocr_cache / page.img_path).with_suffix(".json")
                if json_path.is_file():
                    continue
                json_path.parent.mkdir(parents=True, exist_ok=True)

                pageDict: dict = page.__dict__
                pageDict.pop("img_path")
                dump_json(pageDict, json_path)

        img_paths = volume.get_img_paths()

        for img_path_rel in tqdm(img_paths.values(), desc="Processing pages..."):
            try:
                json_path = (volume.path_ocr_cache / Path(img_path_rel)).with_suffix(".json")

                try:
                    load_json(json_path)
                    already_processed: bool = True
                except (FileNotFoundError, JSONDecodeError, UnicodeDecodeError):
                    already_processed = False

                if no_cache or not already_processed:
                    self.init_models()

                    if self.mpocr is None:
                        raise ValueError

                    result = self.mpocr(volume.path_in / img_path_rel)

                    json_path.parent.mkdir(parents=True, exist_ok=True)
                    dump_json(result, json_path)
            except Exception as e:
                if ignore_errors:
                    logger.error(e)
                else:
                    raise e

        self.generate_mokuro_file(volume, ignore_errors=ignore_errors)

    @staticmethod
    def generate_mokuro_file(volume: Volume, ignore_errors=False):
        json_paths = volume.get_json_paths()
        img_paths = volume.get_img_paths()

        if volume.title is None:
            raise ValueError

        out = {
            "version": __version__,
            "title": volume.title.name,
            "title_uuid": volume.title.uuid,
            "volume": volume.name,
            "volume_uuid": volume.uuid,
            "pages": [],
        }

        for key, json_path_rel in json_paths.items():
            try:
                img_path_rel = img_paths[key]
                page_json = load_json(volume.path_ocr_cache / json_path_rel)
                page_json["img_path"] = str(img_path_rel).replace("\\", "/")
                out["pages"].append(page_json)
            except Exception as e:
                if ignore_errors:
                    logger.error(e)
                else:
                    raise e

        dump_json(out, volume.path_mokuro)

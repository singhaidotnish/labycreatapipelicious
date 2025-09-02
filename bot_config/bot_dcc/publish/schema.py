from dataclasses import dataclass, field
from typing import List, Dict

@dataclass
class Representation:
    name: str
    path: str
    ext: str | None = None
    md5: str | None = None
    size: int | None = None

@dataclass
class PublishContext:
    project: str
    seq: str
    shot: str
    task: str
    version: int
    user: str
    fps: float
    resolution: tuple[int, int]
    data: Dict = field(default_factory=dict)
    representations: List[Representation] = field(default_factory=list)

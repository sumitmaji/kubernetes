from dataclasses import dataclass, field
from typing import List, Optional

@dataclass
class Command:
    command: str
    command_id: int

@dataclass
class BatchMessage:
    commands: List[Command]
    token: str
    batch_id: str
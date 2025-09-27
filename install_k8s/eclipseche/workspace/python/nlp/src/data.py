from datasets import load_dataset
from typing import Dict

def load_text_classification_dataset(name: str = "ag_news"):
    """
    Loads a text classification dataset with 'text' and 'label' columns.
    Defaults to AG News (train/test).
    """
    if name == "ag_news":
        ds = load_dataset("ag_news")
        ds = ds.rename_column("text", "text")
        return ds, 4  # 4 labels
    elif name == "imdb":
        ds = load_dataset("imdb")
        return ds, 2  # binary
    else:
        # Fallback: try hub by name
        ds = load_dataset(name)
        # Best effort inference
        num_labels = len(set(ds["train"]["label"]))
        return ds, num_labels

def build_tokenize_fn(tokenizer, text_key: str = "text", max_length: int = 256):
    def tokenize_fn(batch: Dict):
        return tokenizer(batch[text_key], truncation=True, padding="max_length", max_length=max_length)
    return tokenize_fn

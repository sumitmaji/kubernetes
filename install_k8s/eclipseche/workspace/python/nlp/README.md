# NLP Project Scaffold

A batteries-included starter for Natural Language Processing using the 🤗 Hugging Face ecosystem.

## What's inside?
- `src/train.py` — fine-tunes a Transformer (DistilBERT by default) on a text classification dataset (AG News).
- `src/model.py` — model & tokenizer loader helpers.
- `src/data.py` — dataset loading & preprocessing with Hugging Face `datasets`.
- `notebooks/starter.ipynb` — an interactive notebook with EDA, tokenization preview, and a quick training run.
- `requirements.txt` — common NLP libs (Transformers, Datasets, Accelerate, spaCy optional).
- `Dockerfile` — containerized environment.

## Quickstart
```bash
python3 -m venv .venv && source .venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt

# Optional: spaCy model
python -m spacy download en_core_web_sm

# Train (CPU or GPU if available)
python -m src.train --model distilbert-base-uncased --dataset ag_news --epochs 1
```

## Run notebook
```bash
jupyter notebook notebooks/starter.ipynb
```

## Docker (optional)
```bash
docker build -t nlp-project .
docker run -it --rm -p 8888:8888 nlp-project
```

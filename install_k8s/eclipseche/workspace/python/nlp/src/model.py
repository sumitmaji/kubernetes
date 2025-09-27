from transformers import AutoTokenizer, AutoModelForSequenceClassification

def load_tokenizer(model_name: str):
    return AutoTokenizer.from_pretrained(model_name)

def load_model(model_name: str, num_labels: int):
    return AutoModelForSequenceClassification.from_pretrained(model_name, num_labels=num_labels)

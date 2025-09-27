import argparse
import numpy as np
import evaluate
from transformers import TrainingArguments, Trainer, DataCollatorWithPadding

from .model import load_model, load_tokenizer
from .data import load_text_classification_dataset, build_tokenize_fn

def parse_args():
    p = argparse.ArgumentParser(description="Fine-tune a Transformer for text classification")
    p.add_argument("--model", default="distilbert-base-uncased", help="Hugging Face model name")
    p.add_argument("--dataset", default="ag_news", help="Dataset name: ag_news | imdb | <hub_dataset>")
    p.add_argument("--epochs", type=int, default=1)
    p.add_argument("--batch_size", type=int, default=16)
    p.add_argument("--lr", type=float, default=5e-5)
    p.add_argument("--max_length", type=int, default=256)
    return p.parse_args()

def main():
    args = parse_args()

    # Load dataset
    ds, num_labels = load_text_classification_dataset(args.dataset)

    # Tokenizer & tokenization
    tokenizer = load_tokenizer(args.model)
    tokenize_fn = build_tokenize_fn(tokenizer, max_length=args.max_length)
    ds_tokenized = ds.map(tokenize_fn, batched=True)
    ds_tokenized = ds_tokenized.rename_column("label", "labels")
    ds_tokenized.set_format(type="torch", columns=["input_ids", "attention_mask", "labels"])

    # Model
    model = load_model(args.model, num_labels=num_labels)

    # Metrics
    accuracy = evaluate.load("accuracy")
    f1 = evaluate.load("f1")

    def compute_metrics(eval_pred):
        logits, labels = eval_pred
        preds = np.argmax(logits, axis=-1)
        return {
            "accuracy": accuracy.compute(predictions=preds, references=labels)["accuracy"],
            "f1": f1.compute(predictions=preds, references=labels, average="weighted")["f1"],
        }

    # Trainer
    collator = DataCollatorWithPadding(tokenizer=tokenizer)
    training_args = TrainingArguments(
        output_dir="checkpoints",
        evaluation_strategy="epoch",
        save_strategy="epoch",
        learning_rate=args.lr,
        per_device_train_batch_size=args.batch_size,
        per_device_eval_batch_size=args.batch_size,
        num_train_epochs=args.epochs,
        weight_decay=0.01,
        logging_steps=50,
        load_best_model_at_end=True,
        metric_for_best_model="accuracy",
    )

    trainer = Trainer(
        model=model,
        args=training_args,
        train_dataset=ds_tokenized["train"],
        eval_dataset=ds_tokenized["test"],
        tokenizer=tokenizer,
        data_collator=collator,
        compute_metrics=compute_metrics,
    )

    trainer.train()
    metrics = trainer.evaluate()
    print(metrics)

if __name__ == "__main__":
    main()

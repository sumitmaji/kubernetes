import tensorflow as tf
from src.model import build_model

def main():
    # Load dataset
    (x_train, y_train), (x_test, y_test) = tf.keras.datasets.mnist.load_data()
    x_train, x_test = x_train / 255.0, x_test / 255.0

    # Build model
    model = build_model((28, 28))

    # Train
    model.fit(x_train, y_train, epochs=5, validation_data=(x_test, y_test))

    # Evaluate
    loss, acc = model.evaluate(x_test, y_test)
    print(f"Test Accuracy: {acc:.4f}")

if __name__ == "__main__":
    main()

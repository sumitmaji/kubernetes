import pika
import uuid
import logging
import json
from common.batch_message import BatchMessage, Command

API_TOKEN = 'supersecrettoken'
RESULTS_QUEUE = 'results'

logging.basicConfig(filename='controller.log', level=logging.INFO, format='%(asctime)s %(levelname)s %(message)s')

def send_batch(commands):
    connection = pika.BlockingConnection(pika.ConnectionParameters('localhost'))
    channel = connection.channel()
    channel.queue_declare(queue='commands')
    batch_id = str(uuid.uuid4())
    batch_msg = BatchMessage(
        commands=[Command(command=c, command_id=i) for i, c in enumerate(commands)],
        token=API_TOKEN,
        batch_id=batch_id
    )
    message = json.dumps(batch_msg, default=lambda o: o.__dict__)
    channel.basic_publish(exchange='', routing_key='commands', body=message)
    logging.info(f"Sent batch {batch_id}: commands={commands}")
    connection.close()
    return batch_id

def stream_results(batch_id):
    def callback(ch, method, properties, body):
        result = json.loads(body)
        if result.get('batch_id') == batch_id:
            print(f"Result for command {result['command_id']}: {result['output']}")
            logging.info(f"Streamed result for batch {batch_id}, command {result['command_id']}: {result['output'].strip()}")
        ch.basic_ack(delivery_tag=method.delivery_tag)

    connection = pika.BlockingConnection(pika.ConnectionParameters('localhost'))
    channel = connection.channel()
    channel.queue_declare(queue=RESULTS_QUEUE)
    channel.basic_consume(queue=RESULTS_QUEUE, on_message_callback=callback)
    print(f"Streaming results for batch {batch_id}... Press Ctrl+C to exit.")
    try:
        channel.start_consuming()
    except KeyboardInterrupt:
        print("Stopped streaming.")
        channel.stop_consuming()
    connection.close()

if __name__ == '__main__':
    commands = ['ls', 'whoami', 'uptime']
    batch_id = send_batch(commands)
    stream_results(batch_id)
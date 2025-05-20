import pika
import uuid
import logging
from common.command_message import CommandMessage
import json

API_TOKEN = 'supersecrettoken'

logging.basicConfig(filename='controller.log', level=logging.INFO, format='%(asctime)s %(levelname)s %(message)s')

def send_command(command):
    # Connect to RabbitMQ
    connection = pika.BlockingConnection(pika.ConnectionParameters('localhost'))
    channel = connection.channel()
    channel.queue_declare(queue='commands')
    # Create message
    cmd_msg = CommandMessage(command=command, token=API_TOKEN, request_id=str(uuid.uuid4()))
    message = json.dumps(cmd_msg.__dict__)
    channel.basic_publish(exchange='', routing_key='commands', body=message)
    logging.info(f"Sent command '{command}' with request_id {cmd_msg.request_id}")
    connection.close()

if __name__ == '__main__':
    send_command('whoami')
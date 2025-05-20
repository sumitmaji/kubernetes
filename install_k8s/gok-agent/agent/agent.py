import pika
import subprocess
import logging
import json
from common.command_message import CommandMessage

API_TOKEN = 'supersecrettoken'
ALLOWED_COMMANDS = ['ls', 'whoami', 'uptime']

logging.basicConfig(filename='agent.log', level=logging.INFO, format='%(asctime)s %(levelname)s %(message)s')

def on_message(channel, method, properties, body):
    try:
        msg = json.loads(body)
        command = msg.get('command')
        token = msg.get('token')
        request_id = msg.get('request_id', 'unknown')
        # Authenticate
        if token != API_TOKEN:
            logging.warning(f"Unauthorized command attempt (request_id={request_id}): '{command}'")
            channel.basic_ack(delivery_tag=method.delivery_tag)
            return
        # Command allowlist
        if command.split()[0] not in ALLOWED_COMMANDS:
            logging.warning(f"Forbidden command '{command}' (request_id={request_id})")
            channel.basic_ack(delivery_tag=method.delivery_tag)
            return
        # Execute
        logging.info(f"Executing command '{command}' (request_id={request_id})")
        try:
            result = subprocess.check_output(command, shell=True, stderr=subprocess.STDOUT, timeout=10)
            output = result.decode('utf-8')
            logging.info(f"Command '{command}' succeeded (request_id={request_id}): {output.strip()}")
        except subprocess.CalledProcessError as e:
            output = e.output.decode('utf-8')
            logging.error(f"Command '{command}' failed (request_id={request_id}): {output.strip()}")
        except Exception as e:
            logging.error(f"Exception running '{command}' (request_id={request_id}): {str(e)}")
        finally:
            channel.basic_ack(delivery_tag=method.delivery_tag)
    except Exception as e:
        logging.error(f"Malformed message or processing error: {str(e)}")
        channel.basic_ack(delivery_tag=method.delivery_tag)

def main():
    connection = pika.BlockingConnection(pika.ConnectionParameters('localhost'))
    channel = connection.channel()
    channel.queue_declare(queue='commands')
    channel.basic_qos(prefetch_count=1)
    channel.basic_consume(queue='commands', on_message_callback=on_message)
    logging.info("Agent started, waiting for commands...")
    channel.start_consuming()

if __name__ == '__main__':
    main()
import pika
import subprocess
import logging
import json

API_TOKEN = 'supersecrettoken'
ALLOWED_COMMANDS = ['ls', 'whoami', 'uptime']
RESULTS_QUEUE = 'results'

logging.basicConfig(filename='agent.log', level=logging.INFO, format='%(asctime)s %(levelname)s %(message)s')

def stream_result(channel, batch_id, command_id, output):
    result_msg = {
        'batch_id': batch_id,
        'command_id': command_id,
        'output': output
    }
    channel.basic_publish(exchange='', routing_key=RESULTS_QUEUE, body=json.dumps(result_msg))

def process_command(channel, batch_id, command, command_id):
    if command.split()[0] not in ALLOWED_COMMANDS:
        out = f"Command '{command}' not allowed"
        logging.warning(f"{out} (batch_id={batch_id}, command_id={command_id})")
        stream_result(channel, batch_id, command_id, out)
        return
    try:
        # Use subprocess.Popen for streaming output
        proc = subprocess.Popen(command, shell=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        output_lines = []
        while True:
            line = proc.stdout.readline()
            if not line and proc.poll() is not None:
                break
            if line:
                output_lines.append(line)
                # Stream each line as it arrives
                stream_result(channel, batch_id, command_id, line)
        proc.wait()
        if proc.returncode == 0:
            logging.info(f"Command '{command}' succeeded (batch_id={batch_id}, command_id={command_id})")
        else:
            logging.error(f"Command '{command}' failed (batch_id={batch_id}, command_id={command_id})")
    except Exception as e:
        out = str(e)
        logging.error(f"Exception running '{command}' (batch_id={batch_id}, command_id={command_id}): {out}")
        stream_result(channel, batch_id, command_id, out)

def on_message(ch, method, properties, body):
    try:
        msg = json.loads(body)
        token = msg.get('token')
        batch_id = msg.get('batch_id')
        commands = msg.get('commands', [])
        # Authenticate
        if token != API_TOKEN:
            logging.warning(f"Unauthorized batch (batch_id={batch_id})")
            ch.basic_ack(delivery_tag=method.delivery_tag)
            return
        for cmd in commands:
            command = cmd['command']
            command_id = cmd['command_id']
            process_command(ch, batch_id, command, command_id)
        ch.basic_ack(delivery_tag=method.delivery_tag)
    except Exception as e:
        logging.error(f"Malformed message or processing error: {str(e)}")
        ch.basic_ack(delivery_tag=method.delivery_tag)

def main():
    connection = pika.BlockingConnection(pika.ConnectionParameters('localhost'))
    channel = connection.channel()
    channel.queue_declare(queue='commands')
    channel.queue_declare(queue=RESULTS_QUEUE)
    channel.basic_qos(prefetch_count=1)
    channel.basic_consume(queue='commands', on_message_callback=on_message)
    logging.info("Agent started, waiting for batch commands...")
    channel.start_consuming()

if __name__ == '__main__':
    main()
import pika
import subprocess
import logging
import json
from rbac_config import TOKEN_ROLE_MAP, ROLE_COMMANDS

RESULTS_QUEUE = 'results'

logging.basicConfig(filename='agent.log', level=logging.INFO, format='%(asctime)s %(levelname)s %(message)s')

def get_role(token):
    return TOKEN_ROLE_MAP.get(token)

def is_command_allowed(role, command):
    cmd = command.split()[0]
    return role in ROLE_COMMANDS and cmd in ROLE_COMMANDS[role]

def stream_result(channel, batch_id, command_id, output):
    result_msg = {
        'batch_id': batch_id,
        'command_id': command_id,
        'output': output
    }
    channel.basic_publish(exchange='', routing_key=RESULTS_QUEUE, body=json.dumps(result_msg))

def process_command(channel, batch_id, command, command_id, role):
    if not is_command_allowed(role, command):
        out = f"Role '{role}' not allowed to run '{command}'"
        logging.warning(f"{out} (batch_id={batch_id}, command_id={command_id})")
        stream_result(channel, batch_id, command_id, out)
        return
    try:
        proc = subprocess.Popen(command, shell=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        while True:
            line = proc.stdout.readline()
            if not line and proc.poll() is not None:
                break
            if line:
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
        role = get_role(token)
        if not role:
            logging.warning(f"Unknown token (batch_id={batch_id})")
            ch.basic_ack(delivery_tag=method.delivery_tag)
            return
        for cmd in commands:
            command = cmd['command']
            command_id = cmd['command_id']
            process_command(ch, batch_id, command, command_id, role)
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
def get_users():
    # Dummy data for demonstration
    return [
        {'id': 1, 'name': 'Alice'},
        {'id': 2, 'name': 'Bob'}
    ]

def get_user_by_id(user_id):
    users = get_users()
    for user in users:
        if user['id'] == user_id:
            return user
    return None
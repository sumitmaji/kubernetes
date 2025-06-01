from marshmallow import Schema, fields

class UserSchema(Schema):
    sub = fields.Str(required=True)  # Subject (user id)
    username = fields.Str()
    email = fields.Email()
    name = fields.Str()
    groups = fields.List(fields.Str())
    roles = fields.List(fields.Str())
    token = fields.Str()  
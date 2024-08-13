from flask_wtf import FlaskForm
from wtforms import StringField, PasswordField, IntegerField
from wtforms.validators import DataRequired, Email, Length, NumberRange

class BackupForm(FlaskForm):
    name = StringField('Name', validators=[DataRequired(), Length(min=1, max=100)])
    email = StringField('Email', validators=[DataRequired(), Email(), Length(min=1, max=100)])
    subject = StringField('Subject', validators=[DataRequired(), Length(min=1, max=100)])
    success_keyword = StringField('Success Keyword', validators=[DataRequired(), Length(min=1, max=100)])
    failure_keyword = StringField('Failure Keyword', validators=[DataRequired(), Length(min=1, max=100)])
    interval_hours = IntegerField('Interval Hours', validators=[DataRequired(), NumberRange(min=1, max=168)])

class LoginForm(FlaskForm):
    username = StringField('Username', validators=[DataRequired(), Length(min=1, max=50)])
    password = PasswordField('Password', validators=[DataRequired(), Length(min=1, max=50)])

class MailConfigForm(FlaskForm):
    email = StringField('Email', validators=[DataRequired(), Email(), Length(min=1, max=100)])
    password = PasswordField('Password', validators=[DataRequired(), Length(min=1, max=50)])
    imap_server = StringField('IMAP Server', validators=[DataRequired(), Length(min=1, max=100)])
    imap_port = IntegerField('IMAP Port', validators=[NumberRange(min=1, max=65535)])
    smtp_server = StringField('SMTP Server', validators=[Length(min=1, max=100)])
    smtp_port = IntegerField('SMTP Port', validators=[NumberRange(min=1, max=65535)])

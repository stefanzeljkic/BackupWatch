import datetime
import logging
import os
import sqlite3
import imaplib
import email
from email.header import decode_header
from flask import Flask, render_template, request, redirect, url_for, flash, session, jsonify
from flask_wtf import FlaskForm
from wtforms import StringField, PasswordField, IntegerField
from wtforms.validators import DataRequired, Email, Length, NumberRange
from werkzeug.security import generate_password_hash, check_password_hash
import bleach
from functools import wraps
from dotenv import load_dotenv
from logging.handlers import RotatingFileHandler
import requests
import zipfile
import shutil
import json

# Load environment variables from .env file
load_dotenv()

app = Flask(__name__)
app.secret_key = os.getenv('SECRET_KEY')
app.config.update(
    SESSION_COOKIE_HTTPONLY=True,
    SESSION_COOKIE_SECURE=True,  # This will work only if using HTTPS
    SESSION_COOKIE_SAMESITE='Lax'
)

# Email server details
EMAIL = os.getenv('EMAIL')
PASSWORD = os.getenv('PASSWORD')
IMAP_SERVER = os.getenv('IMAP_SERVER')
IMAP_PORT = int(os.getenv('IMAP_PORT'))
SMTP_SERVER = os.getenv('SMTP_SERVER')
SMTP_PORT = int(os.getenv('SMTP_PORT'))

# Application settings
REFRESH_INTERVAL = int(os.getenv('REFRESH_INTERVAL', 60))
PORT = int(os.getenv('PORT', 8000))

# User roles
ROLES = ["Guest", "Moderator", "Admin"]

# Load version from config file
def load_config():
    config_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'config.json')
    with open(config_path, 'r') as f:
        return json.load(f)

config = load_config()
CURRENT_VERSION = config.get('version', '1.0.0')

# GitHub API Details
GITHUB_API_URL = "https://api.github.com/repos/{owner}/{repo}/releases/latest"
REPO_OWNER = "your-github-username"
REPO_NAME = "your-repo-name"
DOWNLOAD_DIR = "/path/to/download"
EXTRACT_DIR = "/path/to/extract"
APP_DIR = "/path/to/app"

# Configure logging
if not os.path.exists('logs'):
    os.makedirs('logs')

# Rotating file handler for logging
log_filename = datetime.datetime.now().strftime("logs/log_%Y-%m-%d.log")
handler = RotatingFileHandler(log_filename, maxBytes=10*1024*1024, backupCount=10)
handler.setLevel(logging.DEBUG)
formatter = logging.Formatter('%(asctime)s %(levelname)s: %(message)s')
handler.setFormatter(formatter)
logging.getLogger().addHandler(handler)

# Avoid logging sensitive information
logging.getLogger('werkzeug').disabled = True

app.logger.setLevel(logging.DEBUG)

# Connect to SQLite database
def get_db_connection():
    conn = sqlite3.connect('database.db')
    conn.row_factory = sqlite3.Row
    return conn

# Initialize the database
def init_db():
    conn = get_db_connection()
    conn.execute('''CREATE TABLE IF NOT EXISTS backups
                    (id INTEGER PRIMARY KEY AUTOINCREMENT,
                     name TEXT NOT NULL,
                     email TEXT NOT NULL,
                     subject TEXT NOT NULL,
                     success_keyword TEXT NOT NULL,
                     failure_keyword TEXT NOT NULL,
                     last_checked DATE,
                     interval_hours INTEGER NOT NULL DEFAULT 24,
                     status TEXT NOT NULL DEFAULT 'green',
                     position_x INTEGER DEFAULT 0,
                     position_y INTEGER DEFAULT 0)''')
    conn.execute('''CREATE TABLE IF NOT EXISTS users
                    (id INTEGER PRIMARY KEY AUTOINCREMENT,
                     username TEXT NOT NULL UNIQUE,
                     password TEXT NOT NULL,
                     role TEXT NOT NULL)''')
    conn.commit()
    conn.close()

# Create initial admin user
def create_admin_user():
    conn = get_db_connection()
    admin_user = conn.execute('SELECT * FROM users WHERE username = ?', ('admin',)).fetchone()
    if not admin_user:
        admin_password = generate_password_hash('admin')
        conn.execute('INSERT INTO users (username, password, role) VALUES (?, ?, ?)',
                     ('admin', admin_password, 'Admin'))
        conn.commit()
        logging.info("Admin user created.")
    else:
        logging.info("Admin user already exists.")
    conn.close()

init_db()
create_admin_user()

# Forms
from forms import BackupForm, LoginForm, MailConfigForm

def test_email_connection(email, password, imap_server, imap_port):
    try:
        mail = imaplib.IMAP4_SSL(imap_server, imap_port)
        mail.login(email, password)
        mail.logout()
        return True
    except Exception as e:
        logging.error(f"Failed to connect to email server: {e}")
        return False

# Connect to the email server and check emails
def check_email():
    logging.info("Starting email check")
    try:
        mail = imaplib.IMAP4_SSL(IMAP_SERVER, IMAP_PORT)
        mail.login(EMAIL, PASSWORD)
        mail.select("inbox")

        now = datetime.datetime.now()

        with get_db_connection() as conn:
            backups = conn.execute('SELECT * FROM backups').fetchall()

        for backup in backups:
            logging.info(f"Checking emails for backup: {backup['name']} (ID: {backup['id']})")
            status, messages = mail.search(None, f'(FROM "{backup["email"]}" SUBJECT "{backup["subject"]}")')
            email_ids = messages[0].split()

            backup_status = 'red'
            if email_ids:
                latest_email_id = email_ids[-1]
                _, msg = mail.fetch(latest_email_id, "(RFC822)")
                for response_part in msg:
                    if isinstance(response_part, tuple):
                        msg = email.message_from_bytes(response_part[1])
                        body = ""
                        if msg.is_multipart():
                            for part in msg.walk():
                                if part.get_content_type() == "text/plain":
                                    try:
                                        body = part.get_payload(decode=True).decode()
                                    except UnicodeDecodeError:
                                        try:
                                            body = part.get_payload(decode=True).decode('latin1')
                                        except UnicodeDecodeError:
                                            body = part.get_payload(decode=True).decode('utf-8', 'ignore')
                                    break
                        else:
                            try:
                                body = msg.get_payload(decode=True).decode()
                            except UnicodeDecodeError:
                                try:
                                    body = msg.get_payload(decode=True).decode('latin1')
                                except UnicodeDecodeError:
                                    body = part.get_payload(decode=True).decode('utf-8', 'ignore')

                        logging.info(f"Email body for backup '{backup['name']}']: {body}")

                        if backup["success_keyword"] in body:
                            backup_status = 'green'
                        elif backup["failure_keyword"] in body:
                            backup_status = 'red'

                        email_date = msg["Date"]
                        email_datetime = datetime.datetime.strptime(email_date, "%a, %d %b %Y %H:%M:%S %z").replace(tzinfo=None)

                        with get_db_connection() as conn:
                            conn.execute('UPDATE backups SET status = ?, last_checked = ? WHERE id = ?',
                                         (backup_status, email_datetime.strftime("%Y-%m-%d %H:%M:%S"), backup["id"]))
                            logging.info(f"Backup '{backup['name']}' (ID: {backup['id']}) updated with status '{backup_status}' and last_checked '{email_datetime.strftime('%Y-%m-%d %H:%M:%S')}'")
            else:
                last_checked = backup["last_checked"]
                if last_checked:
                    last_checked = datetime.datetime.strptime(last_checked, "%Y-%m-%d %H:%M:%S")
                else:
                    last_checked = now
                diff_hours = (now - last_checked).total_seconds() / 3600
                logging.info(f"Checking backup '{backup['name']}'] (ID: {backup['id']}) with last_checked '{backup['last_checked']}' and diff_hours '{diff_hours}'")
                if diff_hours >= backup["interval_hours"] * 2:
                    backup_status = 'purple'
                elif diff_hours >= backup["interval_hours"]:
                    backup_status = 'yellow'
                else:
                    backup_status = backup["status"]  # retain current status if within interval

                logging.info(f"Calculated status for backup '{backup['name']}' (ID: {backup['id']}) as '{backup_status}'")

                with get_db_connection() as conn:
                    conn.execute('UPDATE backups SET status = ?, last_checked = ? WHERE id = ?',
                                 (backup_status, now.strftime("%Y-%m-%d %H:%M:%S"), backup["id"]))
                    logging.info(f"Backup '{backup['name']}' (ID: {backup['id']}) checked with status '{backup_status}' and last_checked '{now.strftime('%Y-%m-%d %H:%M:%S')}'")

        mail.logout()
        logging.info("Email check completed")
        
    except TimeoutError:
        logging.error("Timeout error occurred while trying to connect to the email server.")
        flash("Failed to connect to the email server due to timeout. Please check your server settings and try again.", "danger")
    except imaplib.IMAP4.error as e:
        logging.error(f"IMAP error occurred: {e}")
        flash(f"IMAP error: {str(e)}. Please check your server settings and try again.", "danger")
    except Exception as e:
        logging.error(f"An unexpected error occurred: {e}")
        flash(f"An unexpected error occurred: {str(e)}. Please try again later.", "danger")


@app.route('/login', methods=['GET', 'POST'])
def login():
    form = LoginForm()
    if form.validate_on_submit():
        username = form.username.data
        password = form.password.data
        print(f"Login attempt: username={username}")  # Debug print
        conn = get_db_connection()
        user = conn.execute('SELECT * FROM users WHERE username = ?', (username,)).fetchone()
        conn.close()
        if user:
            print(f"User found: {user['username']}")  # Debug print
            if check_password_hash(user['password'], password):
                print("Password check passed")  # Debug print
                session['logged_in'] = True
                session['username'] = user['username']
                session['role'] = user['role']
                return redirect(url_for('index'))
            else:
                print("Password check failed")  # Debug print
        else:
            print("User not found")  # Debug print
        flash('Incorrect username or password.', 'danger')
    else:
        print("Form validation failed")  # Debug print
    return render_template('login.html', form=form)

@app.route('/logout')
def logout():
    session.pop('logged_in', None)
    session.pop('username', None)
    session.pop('role', None)
    return redirect(url_for('login'))

def login_required(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if 'logged_in' not in session:
            return redirect(url_for('login'))
        return f(*args, **kwargs)
    return decorated_function

def role_required(*roles):
    def wrapper(f):
        @wraps(f)
        def decorated_function(*args, **kwargs):
            if 'role' not in session or session['role'] not in roles:
                flash('You are not authorized for this action.', 'danger')
                return redirect(url_for('index'))
            return f(*args, **kwargs)
        return decorated_function
    return wrapper

@app.route('/')
@login_required
def index():
    logging.info(f"Current session role: {session.get('role')}")
    conn = get_db_connection()
    backups = conn.execute('SELECT * FROM backups').fetchall()
    conn.close()
    backups = [dict(backup) for backup in backups]

    now = datetime.datetime.now()
    for backup in backups:
        if backup['last_checked']:
            last_checked = datetime.datetime.strptime(backup['last_checked'], "%Y-%m-%d %H:%M:%S")
        else:
            last_checked = now
        elapsed_time = (now - last_checked).total_seconds() / 3600
        backup['elapsed_time'] = round(elapsed_time, 2)

        if elapsed_time < backup['interval_hours']:
            if backup['status'] == 'green':
                backup['status'] = 'green'
            elif backup['status'] == 'red':
                backup['status'] = 'red'
        elif elapsed_time >= backup['interval_hours'] * 2:
            backup['status'] = 'purple'
        elif elapsed_time >= backup['interval_hours']:
            backup['status'] = 'yellow'

    logging.info(f"Backups from database: {backups}")
    return render_template('index.html', backups=backups, refresh_interval=REFRESH_INTERVAL)

@app.route('/add', methods=('GET', 'POST'))
@login_required
@role_required('Admin', 'Moderator')
def add():
    form = BackupForm()
    if form.validate_on_submit():
        name = bleach.clean(form.name.data)
        email = bleach.clean(form.email.data)
        subject = bleach.clean(form.subject.data)
        success_keyword = bleach.clean(form.success_keyword.data)
        failure_keyword = bleach.clean(form.failure_keyword.data)
        interval_hours = form.interval_hours.data

        print(f"Adding new backup: {name}, {email}, {subject}, {success_keyword}, {failure_keyword}, {interval_hours}")  # Debug print

        conn = get_db_connection()
        existing_backup = conn.execute('SELECT * FROM backups WHERE name = ?', (name,)).fetchone()
        if existing_backup:
            conn.close()
            flash('Backup with that name already exists.', 'danger')
            return redirect(url_for('add'))

        conn.execute('INSERT INTO backups (name, email, subject, success_keyword, failure_keyword, interval_hours) VALUES (?, ?, ?, ?, ?, ?)',
                     (name, email, subject, success_keyword, failure_keyword, interval_hours))
        conn.commit()
        conn.close()
        logging.info(f"Added new backup: {name}, {email}, {subject}, {success_keyword}, {failure_keyword, interval_hours}")
        flash('Backup successfully added.', 'success')
        return redirect(url_for('index'))

    return render_template('add.html', form=form)

@app.route('/edit/<int:id>', methods=('GET', 'POST'))
@login_required
@role_required('Admin', 'Moderator')
def edit(id):
    form = BackupForm()
    conn = get_db_connection()
    backup = conn.execute('SELECT * FROM backups WHERE id = ?', (id,)).fetchone()

    if request.method == 'POST' and form.validate_on_submit():
        name = bleach.clean(form.name.data)
        email = bleach.clean(form.email.data)
        subject = bleach.clean(form.subject.data)
        success_keyword = bleach.clean(form.success_keyword.data)
        failure_keyword = bleach.clean(form.failure_keyword.data)
        interval_hours = form.interval_hours.data

        print(f"Updating backup: {name}, {email}, {subject}, {success_keyword}, {failure_keyword}, {interval_hours}")  # Debug print

        conn.execute('UPDATE backups SET name = ?, email = ?, subject = ?, success_keyword = ?, failure_keyword = ?, interval_hours = ? WHERE id = ?',
                     (name, email, subject, success_keyword, failure_keyword, interval_hours, id))
        conn.commit()
        conn.close()
        logging.info(f"Updated backup: {id}, {name}, {email}, {subject}, {success_keyword}, {failure_keyword, interval_hours}")
        flash('Data successfully saved.', 'success')
        return redirect(url_for('index'))

    form.name.data = backup['name']
    form.email.data = backup['email']
    form.subject.data = backup['subject']
    form.success_keyword.data = backup['success_keyword']
    form.failure_keyword.data = backup['failure_keyword']
    form.interval_hours.data = backup['interval_hours']
    conn.close()
    return render_template('edit.html', form=form, backup=backup)

@app.route('/delete/<int:id>', methods=('POST',))
@login_required
@role_required('Admin', 'Moderator')
def delete(id):
    conn = get_db_connection()
    conn.execute('DELETE FROM backups WHERE id = ?', (id,))
    conn.commit()
    conn.close()
    logging.info(f"Deleted backup with ID: {id}")
    return redirect(url_for('index'))

@app.route('/update_position/<int:id>', methods=['POST'])
@login_required
@role_required('Admin', 'Moderator')
def update_position(id):
    position_x = request.form['position_x']
    position_y = request.form['position_y']

    conn = get_db_connection()
    conn.execute('UPDATE backups SET position_x = ?, position_y = ? WHERE id = ?',
                 (position_x, position_y, id))
    conn.commit()
    conn.close()

    return '', 204

@app.route('/check')
@login_required
def check():
    check_email()
    return redirect(url_for('index'))

@app.route('/mail_config', methods=['GET', 'POST'])
@login_required
@role_required('Admin')
def mail_config():
    global EMAIL, PASSWORD, IMAP_SERVER, IMAP_PORT, SMTP_SERVER, SMTP_PORT
    DEFAULT_IMAP_PORT = 993
    DEFAULT_SMTP_PORT = 587
    
    form = MailConfigForm()
    if form.validate_on_submit():
        EMAIL = bleach.clean(form.email.data)
        PASSWORD = bleach.clean(form.password.data) or PASSWORD
        IMAP_SERVER = bleach.clean(form.imap_server.data)
        IMAP_PORT = form.imap_port.data if form.imap_port.data else DEFAULT_IMAP_PORT
        SMTP_SERVER = bleach.clean(form.smtp_server.data) if form.smtp_server.data else SMTP_SERVER
        SMTP_PORT = form.smtp_port.data if form.smtp_port.data else DEFAULT_SMTP_PORT

        if test_email_connection(EMAIL, PASSWORD, IMAP_SERVER, IMAP_PORT):
            flash("Successfully connected to email server", "success")
        else:
            flash("Failed to connect to email server. Please check the details and try again.", "danger")
            return redirect(url_for('mail_config'))

        return redirect(url_for('admin'))
    
    return render_template('mail_config.html', form=form, email=EMAIL, password=PASSWORD, imap_server=IMAP_SERVER, imap_port=IMAP_PORT, smtp_server=SMTP_SERVER, smtp_port=SMTP_PORT)

@app.route('/account_config', methods=['GET', 'POST'])
@login_required
def account_config():
    username = session.get('username')
    role = session.get('role')

    conn = get_db_connection()
    user = conn.execute('SELECT * FROM users WHERE username = ?', (username,)).fetchone()
    conn.close()

    if request.method == 'POST':
        if role == 'Admin':
            username = request.form['username']
            password = request.form['password']
            user_id = request.form['user_id']
            user_role = request.form['role']
            conn = get_db_connection()
            user = conn.execute('SELECT * FROM users WHERE id = ?', (user_id,)).fetchone()
            if password == '********':
                hashed_password = user['password']
            else:
                hashed_password = generate_password_hash(password)
            conn.execute('UPDATE users SET username = ?, password = ?, role = ? WHERE id = ?',
                         (username, hashed_password, user_role, user_id))
            conn.commit()
            conn.close()
            flash("User data successfully updated", "success")
            return redirect(url_for('account_config'))
        else:
            password = request.form['password']
            user_id = request.form['user_id']
            hashed_password = generate_password_hash(password)
            conn = get_db_connection()
            conn.execute('UPDATE users SET password = ? WHERE id = ?',
                         (hashed_password, user_id))
            conn.commit()
            conn.close()
            flash("Password successfully changed", "success")
            return redirect(url_for('account_config'))

    if role == 'Admin':
        conn = get_db_connection()
        users = conn.execute('SELECT * FROM users').fetchall()
        conn.close()
        return render_template('account_config.html', users=users, roles=ROLES, admin=True)
    else:
        return render_template('account_config.html', user=user, roles=ROLES, admin=False)

@app.route('/update_user/<int:id>', methods=['POST'])
@login_required
@role_required('Admin')
def update_user(id):
    username = request.form['username']
    password = request.form['password']
    role = request.form['role']

    conn = get_db_connection()
    user = conn.execute('SELECT * from users WHERE id = ?', (id,)).fetchone()

    if password == '********':
        hashed_password = user['password']
    else:
        hashed_password = generate_password_hash(password)

    conn.execute('UPDATE users SET username = ?, password = ?, role = ? WHERE id = ?',
                 (username, hashed_password, role, id))
    conn.commit()
    conn.close()
    flash("User data successfully updated", "success")
    return redirect(url_for('account_config'))

@app.route('/add_user', methods=['POST'])
@login_required
@role_required('Admin')
def add_user():
    username = request.form['username']
    password = request.form['password']
    role = request.form['role']

    # Hash the password
    hashed_password = generate_password_hash(password)

    conn = get_db_connection()
    conn.execute('INSERT INTO users (username, password, role) VALUES (?, ?, ?)',
                 (username, hashed_password, role))
    conn.commit()
    conn.close()
    flash("New user successfully added", "success")
    return redirect(url_for('account_config'))

@app.route('/delete_user/<int:id>', methods=['POST'])
@login_required
@role_required('Admin')
def delete_user(id):
    conn = get_db_connection()
    conn.execute('DELETE FROM users WHERE id = ?', (id,))
    conn.commit()
    conn.close()
    flash("User successfully deleted", "success")
    return redirect(url_for('account_config'))

@app.route('/check_email_connection')
def check_email_connection():
    if test_email_connection(EMAIL, PASSWORD, IMAP_SERVER, IMAP_PORT):
        return jsonify(success=True)
    else:
        return jsonify(success=False)

@app.route('/donate')
def donate():
    return render_template('donate.html')

@app.route('/documentation')
def documentation():
    return render_template('documentation.html')

@app.route('/admin')
@role_required('Admin')
def admin():
    current_version = config.get('version', 'N/A')
    return render_template('admin.html', current_version=current_version)

@app.route('/version_update')
@role_required('Admin')
def version_update():
    current_version = config.get('version', 'N/A')
    return render_template('version_update.html', current_version=current_version)

def get_latest_version():
    url = GITHUB_API_URL.format(owner=REPO_OWNER, repo=REPO_NAME)
    response = requests.get(url)
    if response.status_code == 200:
        return response.json()
    return None

def download_and_extract_latest_version(url, download_dir, extract_dir):
    local_filename = os.path.join(download_dir, url.split('/')[-1])
    with requests.get(url, stream=True) as r:
        r.raise_for_status()
        with open(local_filename, 'wb') as f:
            for chunk in r.iter_content(chunk_size=8192):
                f.write(chunk)
    with zipfile.ZipFile(local_filename, 'r') as zip_ref:
        zip_ref.extractall(extract_dir)
    return extract_dir

def update_application(latest_release):
    asset = latest_release['assets'][0]
    download_url = asset['browser_download_url']
    extracted_dir = download_and_extract_latest_version(download_url, DOWNLOAD_DIR, EXTRACT_DIR)
    # Replace the application files
    for item in os.listdir(extracted_dir):
        s = os.path.join(extracted_dir, item)
        d = os.path.join(APP_DIR, item)
        if os.path.isdir(s):
            shutil.copytree(s, d, dirs_exist_ok=True)
        else:
            shutil.copy2(s, d)
    # Cleanup
    shutil.rmtree(EXTRACT_DIR)
    os.remove(os.path.join(DOWNLOAD_DIR, asset['name']))
    # Update version in config
    config['version'] = latest_release['tag_name']
    save_config(config)

@app.route('/admin_task')
@role_required('Admin')
def admin_task():
    task = request.args.get('task')
    if task == 'version_update':
        latest_release = get_latest_version()
        if latest_release:
            latest_version = latest_release['tag_name']
            update_application(latest_release)
            flash(f"The latest version {latest_version} has been installed. Please restart the application.", "success")
        else:
            flash("Unable to retrieve the latest version from GitHub.", "danger")
        return redirect(url_for('admin'))
    elif task == 'change_port':
        return redirect(url_for('change_port'))
    else:
        flash(f"Task '{task}' completed.", "success")
        return redirect(url_for('admin'))

@app.route('/change_port', methods=['GET', 'POST'])
@role_required('Admin')
def change_port():
    global PORT
    if request.method == 'POST':
        new_port = request.form.get('port')
        if new_port:
            PORT = int(new_port)
            with open('.env', 'r') as file:
                env_lines = file.readlines()
            with open('.env', 'w') as file:
                for line in env_lines:
                    if line.startswith('PORT='):
                        file.write(f'PORT={PORT}\n')
                    else:
                        file.write(line)
            flash(f"Port successfully changed to {new_port}.", "success")
            return redirect(url_for('admin'))
        else:
            flash("Please enter a valid port number.", "danger")
        return redirect(url_for('change_port'))
    return render_template('change_port.html', current_port=PORT)

# Route for Automatic Refresh page
@app.route('/automatic_refresh', methods=['GET', 'POST'])
@role_required('Admin')
def automatic_refresh():
    if request.method == 'POST':
        new_interval = int(request.form.get('refresh_interval', 60))
        # Save new interval to .env file
        with open('.env', 'r') as file:
            env_lines = file.readlines()
        with open('.env', 'w') as file:
            for line in env_lines:
                if line.startswith('REFRESH_INTERVAL='):
                    file.write(f'REFRESH_INTERVAL={new_interval}\n')
                else:
                    file.write(line)
        # Update the in-memory value for immediate effect
        global REFRESH_INTERVAL
        REFRESH_INTERVAL = new_interval
        flash(f"Automatic refresh interval set to {new_interval} seconds.", "success")
        return redirect(url_for('automatic_refresh'))
    return render_template('automatic_refresh.html', refresh_interval=REFRESH_INTERVAL)

# Route for License page
@app.route('/license')
@role_required('Admin')
def license():
    return render_template('license.html')

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=PORT)

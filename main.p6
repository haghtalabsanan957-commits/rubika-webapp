from flask import Flask, render_template_string, request, session, redirect, url_for, jsonify
import json
import os
from datetime import datetime
from functools import wraps

app = Flask(__name__)
app.secret_key = 'rubika_bot_secret_key_2024'

# ==================== فایل‌های دیتابیس ====================
USERS_DB = 'users.json'
CHARGES_DB = 'charges.json'

# ==================== توابع کمکی ====================
def load_json(filename):
    if os.path.exists(filename):
        with open(filename, 'r', encoding='utf-8') as f:
            return json.load(f)
    return {}

def save_json(filename, data):
    with open(filename, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

def get_user(phone):
    users = load_json(USERS_DB)
    return users.get(phone)

def save_user(phone, data):
    users = load_json(USERS_DB)
    users[phone] = data
    save_json(USERS_DB, users)

def get_all_users():
    return load_json(USERS_DB)

def get_charges():
    return load_json(CHARGES_DB)

def save_charge(charge_data):
    charges = get_charges()
    charge_id = f"charge_{datetime.now().strftime('%Y%m%d%H%M%S')}"
    charges[charge_id] = charge_data
    save_json(CHARGES_DB, charges)

def update_charge_status(charge_id, status):
    charges = get_charges()
    if charge_id in charges:
        charges[charge_id]['status'] = status
        save_json(CHARGES_DB, charges)

# ==================== قالب‌های HTML ====================
LOGIN_TEMPLATE = """
<!DOCTYPE html>
<html lang="fa" dir="rtl">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>ورود - ربات روبیکا</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); min-height: 100vh; display: flex; justify-content: center; align-items: center; }
        .login-container { background: white; padding: 40px; border-radius: 10px; box-shadow: 0 10px 25px rgba(0,0,0,0.2); width: 100%; max-width: 400px; }
        h1 { text-align: center; color: #333; margin-bottom: 30px; font-size: 28px; }
        .form-group { margin-bottom: 20px; }
        label { display: block; margin-bottom: 8px; color: #555; font-weight: 600; }
        input { width: 100%; padding: 12px; border: 2px solid #ddd; border-radius: 5px; font-size: 16px; }
        input:focus { outline: none; border-color: #667eea; }
        button { width: 100%; padding: 12px; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; border: none; border-radius: 5px; font-size: 16px; font-weight: 600; cursor: pointer; }
        button:hover { transform: translateY(-2px); }
        .error { color: #dc3545; text-align: center; margin-bottom: 20px; }
        .admin-link { text-align: center; margin-top: 20px; }
        .admin-link a { color: #667eea; text-decoration: none; font-size: 14px; }
    </style>
</head>
<body>
    <div class="login-container">
        <h1>🤖 ربات روبیکا</h1>
        {% if error %}<div class="error">{{ error }}</div>{% endif %}
        <form method="POST" action="/login">
            <div class="form-group">
                <label for="phone">شماره تلفن:</label>
                <input type="tel" id="phone" name="phone" placeholder="09xxxxxxxxx" required>
            </div>
            <button type="submit">ورود</button>
        </form>
        <div class="admin-link">
            <a href="/admin">ورود ادمین</a>
        </div>
    </div>
</body>
</html>
"""

DASHBOARD_TEMPLATE = """
<!DOCTYPE html>
<html lang="fa" dir="rtl">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>داشبورد - ربات روبیکا</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background: #f5f7fa; padding: 20px; }
        .container { max-width: 1000px; margin: 0 auto; }
        .header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 30px; }
        h1 { color: #333; }
        .user-info { background: white; padding: 15px 25px; border-radius: 5px; box-shadow: 0 2px 5px rgba(0,0,0,0.1); }
        .balance { font-size: 18px; color: #27ae60; font-weight: bold; }
        .logout { background: #e74c3c; color: white; padding: 10px 20px; border: none; border-radius: 5px; cursor: pointer; text-decoration: none; }
        .section { background: white; padding: 30px; border-radius: 10px; margin-bottom: 20px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        .section h2 { color: #333; margin-bottom: 20px; border-bottom: 2px solid #667eea; padding-bottom: 10px; }
        .form-group { margin-bottom: 15px; }
        label { display: block; margin-bottom: 8px; color: #555; font-weight: 600; }
        input, select, textarea { width: 100%; padding: 10px; border: 2px solid #ddd; border-radius: 5px; font-size: 14px; font-family: inherit; }
        input:focus, select:focus, textarea:focus { outline: none; border-color: #667eea; }
        textarea { resize: vertical; min-height: 100px; }
        button { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 12px 30px; border: none; border-radius: 5px; cursor: pointer; font-weight: 600; font-size: 16px; }
        button:hover { opacity: 0.9; }
        .groups-list { display: grid; grid-template-columns: repeat(auto-fill, minmax(150px, 1fr)); gap: 10px; margin-bottom: 20px; }
        .group-checkbox { background: white; padding: 15px; border: 2px solid #ddd; border-radius: 5px; cursor: pointer; }
        .group-checkbox input { display: none; }
        .group-checkbox input:checked + label { background: #667eea; color: white; }
        .group-checkbox label { margin: 0; padding: 10px; border-radius: 3px; background: #f0f0f0; cursor: pointer; display: block; text-align: center; }
        .charge-section { background: #ecf0f1; padding: 20px; border-radius: 5px; }
        .charge-history { list-style: none; }
        .charge-history li { padding: 10px; background: #f8f9fa; margin-bottom: 10px; border-radius: 5px; border-right: 4px solid #667eea; }
        .message { padding: 15px; margin-bottom: 15px; border-radius: 5px; }
        .message.success { background: #d4edda; color: #155724; border: 1px solid #c3e6cb; }
        .message.error { background: #f8d7da; color: #721c24; border: 1px solid #f5c6cb; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <div>
                <h1>🤖 ربات روبیکا</h1>
                <p>سلام {{ phone }}</p>
            </div>
            <div style="text-align: left;">
                <div class="user-info">
                    <div class="balance">موجودی: {{ balance }} تومان</div>
                </div>
                <a href="/logout" class="logout">خروج</a>
            </div>
        </div>

        {% if message %}<div class="message {{ message_type }}">{{ message }}</div>{% endif %}

        <div class="section">
            <h2>📤 ارسال پیام</h2>
            <form method="POST" action="/send_message">
                <div class="form-group">
                    <label>انتخاب گروه‌ها:</label>
                    <div class="groups-list">
                        {% for group_id, group_name in groups.items() %}
                        <div class="group-checkbox">
                            <input type="checkbox" id="group_{{ group_id }}" name="groups" value="{{ group_id }}">
                            <label for="group_{{ group_id }}">{{ group_name }}</label>
                        </div>
                        {% endfor %}
                    </div>
                </div>
                <div class="form-group">
                    <label for="message">متن پیام:</label>
                    <textarea id="message" name="message" placeholder="پیام خود را اینجا تایپ کنید..." required></textarea>
                </div>
                <button type="submit">ارسال (هزینه: 5000 تومان)</button>
            </form>
        </div>

        <div class="section">
            <h2>💰 شارژ حساب</h2>
            <div class="charge-section">
                <h3 style="margin-bottom: 15px;">راهنما:</h3>
                <p style="margin-bottom: 15px; color: #555;">
                    ✓ عکس فیش واریز خود را آپلود کنید<br>
                    ✓ شماره کارت: 6037991799815794<br>
                    ✓ تا ۱۵ دقیقه بعد شارژ تایید می‌شود
                </p>
                <form method="POST" enctype="multipart/form-data" action="/upload_receipt">
                    <div class="form-group">
                        <label for="receipt">آپلود عکس فیش:</label>
                        <input type="file" id="receipt" name="receipt" accept="image/*" required>
                    </div>
                    <div class="form-group">
                        <label for="amount">مبلغ (تومان):</label>
                        <input type="number" id="amount" name="amount" min="1000" step="1000" required>
                    </div>
                    <button type="submit">آپلود فیش</button>
                </form>
            </div>

            <h3 style="margin-top: 30px; margin-bottom: 15px;">تاریخچه شارژ:</h3>
            {% if user_charges %}
            <ul class="charge-history">
                {% for charge in user_charges %}
                <li>
                    <strong>{{ charge.amount }} تومان</strong> - 
                    <span style="color: {% if charge.status == 'approved' %}#27ae60{% elif charge.status == 'pending' %}#f39c12{% else %}#e74c3c{% endif %}">
                        {{ charge.status_text }}
                    </span>
                    <br>
                    <small>{{ charge.date }}</small>
                </li>
                {% endfor %}
            </ul>
            {% else %}
            <p style="color: #999;">هنوز شارژی انجام نشده</p>
            {% endif %}
        </div>
    </div>
</body>
</html>
"""

ADMIN_LOGIN_TEMPLATE = """
<!DOCTYPE html>
<html lang="fa" dir="rtl">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>ورود ادمین</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); min-height: 100vh; display: flex; justify-content: center; align-items: center; }
        .login-container { background: white; padding: 40px; border-radius: 10px; box-shadow: 0 10px 25px rgba(0,0,0,0.2); width: 100%; max-width: 400px; }
        h1 { text-align: center; color: #333; margin-bottom: 30px; }
        .form-group { margin-bottom: 20px; }
        label { display: block; margin-bottom: 8px; color: #555; font-weight: 600; }
        input { width: 100%; padding: 12px; border: 2px solid #ddd; border-radius: 5px; font-size: 16px; }
        input:focus { outline: none; border-color: #667eea; }
        button { width: 100%; padding: 12px; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; border: none; border-radius: 5px; font-size: 16px; font-weight: 600; cursor: pointer; }
        button:hover { opacity: 0.9; }
        .error { color: #dc3545; text-align: center; margin-bottom: 20px; }
    </style>
</head>
<body>
    <div class="login-container">
        <h1>🔐 ورود ادمین</h1>
        {% if error %}<div class="error">{{ error }}</div>{% endif %}
        <form method="POST" action="/admin_login">
            <div class="form-group">
                <label for="password">رمز عبور:</label>
                <input type="password" id="password" name="password" required>
            </div>
            <button type="submit">ورود</button>
        </form>
    </div>
</body>
</html>
"""

ADMIN_PANEL_TEMPLATE = """
<!DOCTYPE html>
<html lang="fa" dir="rtl">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>پنل ادمین</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background: #f5f7fa; padding: 20px; }
        .container { max-width: 1200px; margin: 0 auto; }
        .header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 30px; }
        h1 { color: #333; }
        .logout { background: #e74c3c; color: white; padding: 10px 20px; border: none; border-radius: 5px; cursor: pointer; text-decoration: none; }
        .section { background: white; padding: 30px; border-radius: 10px; margin-bottom: 20px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        .section h2 { color: #333; margin-bottom: 20px; }
        table { width: 100%; border-collapse: collapse; }
        th { background: #667eea; color: white; padding: 12px; text-align: right; }
        td { padding: 12px; border-bottom: 1px solid #ddd; }
        tr:hover { background: #f9f9f9; }
        .charge-image { max-width: 100px; height: 100px; cursor: pointer; border-radius: 5px; }
        .status { padding: 5px 10px; border-radius: 3px; font-weight: 600; }
        .status.pending { background: #fff3cd; color: #856404; }
        .status.approved { background: #d4edda; color: #155724; }
        .status.rejected { background: #f8d7da; color: #721c24; }
        .action-btn { padding: 8px 12px; margin: 0 5px; border: none; border-radius: 3px; cursor: pointer; font-weight: 600; }
        .approve { background: #28a745; color: white; }
        .reject { background: #dc3545; color: white; }
        .stats { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px; margin-bottom: 20px; }
        .stat-box { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 20px; border-radius: 10px; text-align: center; }
        .stat-box h3 { font-size: 30px; margin-bottom: 10px; }
        .stat-box p { opacity: 0.9; }
        .modal { display: none; position: fixed; z-index: 1; left: 0; top: 0; width: 100%; height: 100%; background-color: rgba(0,0,0,0.5); }
        .modal-content { background-color: white; margin: auto; padding: 20px; border-radius: 10px; width: 80%; max-width: 600px; top: 50%; left: 50%; transform: translate(-50%, -50%); position: absolute; }
        .close { color: #aaa; float: left; font-size: 28px; font-weight: bold; cursor: pointer; }
        .close:hover { color: black; }
        .modal-image { width: 100%; max-height: 500px; margin-bottom: 20px; border-radius: 5px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🔐 پنل ادمین</h1>
            <a href="/logout" class="logout">خروج</a>
        </div>

        <div class="section">
            <h2>📊 آمار</h2>
            <div class="stats">
                <div class="stat-box">
                    <h3>{{ total_users }}</h3>
                    <p>کاربران کل</p>
                </div>
                <div class="stat-box">
                    <h3>{{ pending_charges }}</h3>
                    <p>درخواست تایید</p>
                </div>
                <div class="stat-box">
                    <h3>{{ total_balance }}</h3>
                    <p>کل موجودی</p>
                </div>
            </div>
        </div>

        <div class="section">
            <h2>📋 درخواست‌های شارژ</h2>
            {% if charges %}
            <table>
                <tr>
                    <th>شماره تلفن</th>
                    <th>مبلغ</th>
                    <th>تاریخ</th>
                    <th>فیش</th>
                    <th>وضعیت</th>
                    <th>عملیات</th>
                </tr>
                {% for charge_id, charge in charges.items() %}
                <tr>
                    <td>{{ charge.phone }}</td>
                    <td>{{ charge.amount }} تومان</td>
                    <td>{{ charge.date }}</td>
                    <td>
                        {% if charge.image_path %}
                        <img src="{{ charge.image_path }}" class="charge-image" onclick="openModal('{{ charge.image_path }}')">
                        {% endif %}
                    </td>
                    <td><span class="status {{ charge.status }}">{{ charge.status_text }}</span></td>
                    <td>
                        {% if charge.status == 'pending' %}
                        <button class="action-btn approve" onclick="approveCharge('{{ charge_id }}')">تایید</button>
                        <button class="action-btn reject" onclick="rejectCharge('{{ charge_id }}')">رد</button>
                        {% endif %}
                    </td>
                </tr>
                {% endfor %}
            </table>
            {% else %}
            <p>هیچ درخواستی وجود ندارد</p>
            {% endif %}
        </div>
    </div>

    <div id="imageModal" class="modal">
        <div class="modal-content">
            <span class="close" onclick="closeModal()">&times;</span>
            <img id="modalImage" class="modal-image">
        </div>
    </div>

    <script>
        function openModal(imagePath) {
            document.getElementById('imageModal').style.display = 'block';
            document.getElementById('modalImage').src = imagePath;
        }
        function closeModal() {
            document.getElementById('imageModal').style.display = 'none';
        }
        function approveCharge(chargeId) {
            if (confirm('تایید این شارژ؟')) {
                fetch('/admin_approve_charge', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ charge_id: chargeId })
                }).then(() => location.reload());
            }
        }
        function rejectCharge(chargeId) {
            if (confirm('این شارژ را رد کنید؟')) {
                fetch('/admin_reject_charge', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ charge_id: chargeId })
                }).then(() => location.reload());
            }
        }
    </script>
</body>
</html>
"""

# ==================== دکوریتورها ====================
def login_required(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if 'phone' not in session:
            return redirect(url_for('login'))
        return f(*args, **kwargs)
    return decorated_function

def admin_required(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if 'admin' not in session:
            return redirect(url_for('admin_login'))
        return f(*args, **kwargs)
    return decorated_function

# ==================== مسیرهای اپ ====================
@app.route('/')
def index():
    if 'admin' in session:
        return redirect(url_for('admin_panel'))
    elif 'phone' in session:
        return redirect(url_for('dashboard'))
    return redirect(url_for('login'))

@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        phone = request.form.get('phone', '').strip()
        
        if not phone:
            return render_template_string(LOGIN_TEMPLATE, error='شماره تلفن را وارد کنید')
        
        if not phone.startswith('09') or len(phone) != 11:
            return render_template_string(LOGIN_TEMPLATE, error='شماره تلفن نامعتبر است')
        
        session['phone'] = phone
        
        user = get_user(phone)
        if not user:
            save_user(phone, {
                'phone': phone,
                'balance': 0,
                'groups': {},
                'created_at': datetime.now().isoformat()
            })
        
        return redirect(url_for('dashboard'))
    
    return render_template_string(LOGIN_TEMPLATE, error=Non

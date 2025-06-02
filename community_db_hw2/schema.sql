import os
import uuid
from flask import Flask, render_template, request, redirect, url_for, session, flash, jsonify
import mysql.connector
from werkzeug.security import generate_password_hash, check_password_hash
from PIL import Image, ImageDraw, ImageFont
import random
from functools import wraps
import datetime

app = Flask(__name__)
app.secret_key = 'a_very_secret_key_for_development' # 修改为一个固定的字符串

# --- Database Configuration ---
DB_CONFIG = {
    'host': 'localhost',
    'user': 'root',
    'password': '123456',
    'database': 'community_database',
    'autocommit': True # 确保DML操作立即生效
}

# --- Database Connection Pool (simple version) ---
def get_db_connection():
    try:
        conn = mysql.connector.connect(**DB_CONFIG)
        return conn
    except mysql.connector.Error as err:
        app.logger.error(f"Database connection failed: {err}")
        return None

# --- Avatar Generation ---
AVATAR_DIR = os.path.join(app.static_folder, 'img', 'avatars')
if not os.path.exists(AVATAR_DIR):
    os.makedirs(AVATAR_DIR)

DEFAULT_AVATAR_COLORS = [
    (170, 204, 238), (255, 182, 193), (152, 251, 152),
    (255, 218, 185), (221, 160, 221), (173, 216, 230)
]

def generate_default_avatar(user_id, username):
    initial = username[0].upper() if username else '?'
    color = random.choice(DEFAULT_AVATAR_COLORS)
    img = Image.new('RGB', (100, 100), color=color)
    draw = ImageDraw.Draw(img)
    try:
        #尝试加载一个常见的字体，如果找不到，则使用Pillow默认字体
        font = ImageFont.truetype("arial.ttf", 60)
    except IOError:
        font = ImageFont.load_default()
    
    text_width, text_height = draw.textbbox((0,0), initial, font=font)[2:] # Pillow 10+
    x = (100 - text_width) / 2
    y = (100 - text_height) / 2
    draw.text((x, y), initial, fill=(255, 255, 255), font=font)
    
    avatar_filename = f"{user_id}_avatar.png"
    avatar_path = os.path.join(AVATAR_DIR, avatar_filename)
    img.save(avatar_path)
    return f'img/avatars/{avatar_filename}'


# --- Decorators ---
def login_required(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if 'user_id' not in session:
            flash('请先登录以访问此页面。', 'warning')
            return redirect(url_for('login'))
        return f(*args, **kwargs)
    return decorated_function

def admin_required(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if 'user_id' not in session:
            flash('请先登录以访问此页面。', 'warning')
            return redirect(url_for('login'))
        if session.get('user_role') != 'admin':
            flash('您没有权限访问此页面。', 'danger')
            return redirect(url_for('homepage'))
        return f(*args, **kwargs)
    return decorated_function

# --- Helper Functions ---
def get_user_by_id(user_id):
    conn = get_db_connection()
    if not conn: return None
    cursor = conn.cursor(dictionary=True)
    cursor.execute("SELECT user_id, user_name, user_role, avatar_url FROM user WHERE user_id = %s", (user_id,))
    user = cursor.fetchone()
    cursor.close()
    conn.close()
    return user

def get_user_avatar(user_id, username):
    conn = get_db_connection()
    if not conn: return url_for('static', filename='img/avatars/default_avatar.png') # Fallback
    cursor = conn.cursor(dictionary=True)
    cursor.execute("SELECT avatar_url FROM user WHERE user_id = %s", (user_id,))
    result = cursor.fetchone()
    cursor.close()
    conn.close()
    if result and result['avatar_url']:
        return url_for('static', filename=result['avatar_url'])
    
    # If no avatar_url, generate and save one (or just return path to a generic default)
    # For simplicity, we assume avatar_url is set during registration or profile update
    # Let's ensure a default is always available if not set
    default_avatar_path = generate_default_avatar(user_id, username) # This generates if not exists
    
    # Update database with this new default avatar if it wasn't there
    conn_update = get_db_connection()
    if conn_update:
        cursor_update = conn_update.cursor()
        try:
            cursor_update.execute("UPDATE user SET avatar_url = %s WHERE user_id = %s AND avatar_url IS NULL", (default_avatar_path, user_id))
            conn_update.commit()
        except mysql.connector.Error as err:
            app.logger.error(f"Error updating avatar_url: {err}")
        finally:
            cursor_update.close()
            conn_update.close()
    return url_for('static', filename=default_avatar_path)


# --- Routes ---
@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        username = request.form['username']
        password = request.form['password']
        
        conn = get_db_connection()
        if not conn:
            flash('数据库连接失败，请稍后再试。', 'danger')
            return render_template('login.html')

        cursor = conn.cursor(dictionary=True)
        cursor.execute("SELECT * FROM user WHERE user_name = %s", (username,))
        user = cursor.fetchone()
        cursor.close()
        conn.close()

        if user and check_password_hash(user['user_password'], password):
            session['user_id'] = user['user_id']
            session['user_name'] = user['user_name']
            session['user_role'] = user['user_role']
            session['avatar_url'] = user.get('avatar_url') or get_user_avatar(user['user_id'], user['user_name'])
            flash('登录成功！', 'success')
            return redirect(url_for('homepage'))
        else:
            flash('用户名或密码无效。', 'danger')
    return render_template('login.html')

@app.route('/register', methods=['GET', 'POST'])
def register():
    if request.method == 'POST':
        username = request.form['username']
        password = request.form['password']
        confirm_password = request.form['confirm_password']

        if password != confirm_password:
            flash('密码不匹配。', 'danger')
            return render_template('register.html')

        conn = get_db_connection()
        if not conn:
            flash('数据库连接失败，请稍后再试。', 'danger')
            return render_template('register.html')
        
        cursor = conn.cursor(dictionary=True)
        cursor.execute("SELECT user_name FROM user WHERE user_name = %s", (username,))
        if cursor.fetchone():
            flash('用户名已存在。', 'danger')
            cursor.close()
            conn.close()
            return render_template('register.html')

        user_id = f"USER{str(uuid.uuid4().int)[:11]}"
        hashed_password = generate_password_hash(password)
        user_role = "user"
        
        # Generate default avatar
        avatar_url = generate_default_avatar(user_id, username)

        try:
            cursor.execute(
                "INSERT INTO user (user_id, user_name, user_password, user_role, avatar_url) VALUES (%s, %s, %s, %s, %s)",
                (user_id, username, hashed_password, user_role, avatar_url)
            )
            conn.commit() # Ensure autocommit=True in DB_CONFIG or commit here
            flash('注册成功！请登录。', 'success')
            return redirect(url_for('login'))
        except mysql.connector.Error as err:
            flash(f'注册失败: {err}', 'danger')
            app.logger.error(f"Registration error: {err}")
        finally:
            cursor.close()
            conn.close()
            
    return render_template('register.html')

@app.route('/logout')
@login_required
def logout():
    session.clear()
    flash('您已成功退出。', 'info')
    return redirect(url_for('login'))

@app.route('/')
@login_required
def homepage():
    conn = get_db_connection()
    if not conn:
        flash('无法加载板块，数据库连接失败。', 'danger')
        return render_template('homepage.html', sections=[])
        
    cursor = conn.cursor(dictionary=True)
    cursor.execute("SELECT section_id, section_name, section_description FROM section")
    sections = cursor.fetchall()
    cursor.close()
    conn.close()
    # user_role is still passed, can be used for other admin-specific UI elements if any
    user_role = session.get('user_role')
    return render_template('homepage.html', sections=sections, user_role=user_role)

@app.route('/create_section', methods=['GET', 'POST'])
@login_required # Changed from @admin_required to allow all logged-in users
def create_section():
    if request.method == 'POST':
        section_name = request.form['section_name']
        section_description = request.form['section_description']

        if not section_name or not section_description:
            flash('板块名称和描述不能为空。', 'danger')
            return render_template('create_section.html')

        conn = get_db_connection()
        if not conn:
            flash('数据库连接失败，请稍后再试。', 'danger')
            return render_template('create_section.html')

        cursor = conn.cursor(dictionary=True)
        # Check if section name already exists
        cursor.execute("SELECT section_id FROM section WHERE section_name = %s", (section_name,))
        if cursor.fetchone():
            flash('该板块名称已存在。', 'danger')
            cursor.close()
            conn.close()
            return render_template('create_section.html', section_name=section_name, section_description=section_description)

        section_id = f"SECTION{str(uuid.uuid4().int)[:8]}" # 修改了这里：[:9] 改为 [:8]

        try:
            cursor.execute(
                "INSERT INTO section (section_id, section_name, section_description) VALUES (%s, %s, %s)",
                (section_id, section_name, section_description)
            )
            # conn.commit() is handled by autocommit=True or should be explicit if not
            flash('板块创建成功！', 'success')
            return redirect(url_for('homepage'))
        except mysql.connector.Error as err:
            flash(f'创建板块失败: {err}', 'danger')
            app.logger.error(f"Create section error: {err}")
        finally:
            cursor.close()
            conn.close()
            
    return render_template('create_section.html')


@app.route('/section/<section_id>')
@login_required
def section_detail(section_id):
    conn = get_db_connection()
    if not conn:
        flash('无法加载板块详情，数据库连接失败。', 'danger')
        return redirect(url_for('homepage'))

    cursor = conn.cursor(dictionary=True)
    cursor.execute("SELECT section_id, section_name, section_description FROM section WHERE section_id = %s", (section_id,))
    section = cursor.fetchone()

    if not section:
        flash('板块未找到。', 'danger')
        return redirect(url_for('homepage'))

    cursor.execute("""
        SELECT p.post_id, p.post_name, p.number_likes, p.create_date, u.user_name as poster_name, u.avatar_url as poster_avatar
        FROM post p
        JOIN user u ON p.poster_id = u.user_id
        WHERE p.section_id_in = %s
        ORDER BY p.create_date DESC
    """, (section_id,))
    posts = cursor.fetchall()
    
    # Ensure avatars for posters
    for post in posts:
        if not post['poster_avatar']: # If avatar_url is NULL in DB
             # This assumes poster_id is available, if not, adjust query
            poster_id_for_avatar = None
            temp_cursor = conn.cursor(dictionary=True) # Need a new cursor or ensure poster_id is in post dict
            temp_cursor.execute("SELECT poster_id FROM post WHERE post_id = %s", (post['post_id'],))
            poster_info = temp_cursor.fetchone()
            if poster_info:
                poster_id_for_avatar = poster_info['poster_id']
            temp_cursor.close()

            if poster_id_for_avatar:
                 post['poster_avatar'] = get_user_avatar(poster_id_for_avatar, post['poster_name'])
            else: # Fallback if somehow poster_id is not found
                 post['poster_avatar'] = url_for('static', filename=generate_default_avatar(f"post_{post['post_id']}", post['poster_name']))


    cursor.close()
    conn.close()
    return render_template('section_detail.html', section=section, posts=posts)


@app.route('/post/<post_id>', methods=['GET', 'POST'])
@login_required
def post_detail(post_id):
    conn = get_db_connection()
    if not conn:
        flash('无法加载帖子详情，数据库连接失败。', 'danger')
        return redirect(url_for('homepage')) # Or previous page

    cursor = conn.cursor(dictionary=True)
    
    # Fetch post details
    cursor.execute("""
        SELECT p.*, u.user_name as poster_name, u.avatar_url as poster_avatar
        FROM post p
        JOIN user u ON p.poster_id = u.user_id
        WHERE p.post_id = %s
    """, (post_id,))
    post = cursor.fetchone()

    if not post:
        flash('帖子未找到。', 'danger')
        cursor.close()
        conn.close()
        return redirect(url_for('homepage')) # Or previous page

    if not post['poster_avatar']:
        post['poster_avatar'] = get_user_avatar(post['poster_id'], post['poster_name'])

    # Fetch comments for the post
    cursor.execute("""
        SELECT c.*, u.user_name as commenter_name, u.avatar_url as commenter_avatar
        FROM comments c
        JOIN user u ON c.commenter_id = u.user_id
        WHERE c.post_id_in = %s
        ORDER BY c.comment_date ASC
    """, (post_id,))
    comments = cursor.fetchall()
    for comment in comments:
        if not comment['commenter_avatar']:
            comment['commenter_avatar'] = get_user_avatar(comment['commenter_id'], comment['commenter_name'])
            
    # Check if current user liked this post
    cursor.execute("SELECT * FROM likes WHERE user_id_like = %s AND post_id_liked = %s", (session['user_id'], post_id))
    user_liked_post = cursor.fetchone() is not None

    cursor.close()
    conn.close()
    return render_template('post_detail.html', post=post, comments=comments, user_liked_post=user_liked_post)

@app.route('/create_post/<section_id>', methods=['GET', 'POST'])
@login_required
def create_post(section_id):
    conn = get_db_connection()
    if not conn:
        flash('数据库连接失败。', 'danger')
        return redirect(url_for('section_detail', section_id=section_id))
        
    cursor = conn.cursor(dictionary=True)
    cursor.execute("SELECT section_name FROM section WHERE section_id = %s", (section_id,))
    section = cursor.fetchone()
    cursor.close() # Close early if section not found
    
    if not section:
        flash('板块未找到。', 'danger')
        conn.close()
        return redirect(url_for('homepage'))

    if request.method == 'POST':
        title = request.form['title']
        content = request.form['content']
        post_id = f"POST{str(uuid.uuid4().int)[:11]}"
        poster_id = session['user_id']
        create_date = datetime.date.today()

        cursor = conn.cursor() # Re-open cursor for insert
        try:
            cursor.execute(
                "INSERT INTO post (post_id, post_name, post_content, poster_id, section_id_in, create_date, number_likes, number_commnets) VALUES (%s, %s, %s, %s, %s, %s, 0, 0)",
                (post_id, title, content, poster_id, section_id, create_date)
            )
            conn.commit()
            flash('帖子创建成功！', 'success')
            return redirect(url_for('post_detail', post_id=post_id))
        except mysql.connector.Error as err:
            flash(f'创建帖子失败: {err}', 'danger')
            app.logger.error(f"Create post error: {err}")
        finally:
            cursor.close()
            conn.close()
    
    # For GET request, or if POST failed and re-rendering form
    if conn.is_connected(): # conn might have been closed if POST failed and returned early
         conn.close()
    return render_template('create_post.html', section_id=section_id, section_name=section['section_name'])


@app.route('/submit_comment/<post_id>', methods=['POST'])
@login_required
def submit_comment(post_id):
    content = request.form['comment_content']
    if not content.strip():
        flash('评论内容不能为空。', 'warning')
        return redirect(url_for('post_detail', post_id=post_id))

    comment_id = f"COMMENT{str(uuid.uuid4().int)[:9]}"
    commenter_id = session['user_id']
    comment_date = datetime.date.today()

    conn = get_db_connection()
    if not conn:
        flash('数据库连接失败，无法发表评论。', 'danger')
        return redirect(url_for('post_detail', post_id=post_id))
    
    cursor = conn.cursor()
    try:
        cursor.execute(
            "INSERT INTO comments (comment_id, commenter_id, post_id_in, comment_content, comment_date) VALUES (%s, %s, %s, %s, %s)",
            (comment_id, commenter_id, post_id, content, comment_date)
        )
        # Update comment count on post
        cursor.execute("UPDATE post SET number_commnets = number_commnets + 1 WHERE post_id = %s", (post_id,))
        conn.commit()
        flash('评论发表成功！', 'success')
    except mysql.connector.Error as err:
        flash(f'评论发表失败: {err}', 'danger')
        app.logger.error(f"Submit comment error: {err}")
    finally:
        cursor.close()
        conn.close()
    return redirect(url_for('post_detail', post_id=post_id))

@app.route('/toggle_like/<post_id>', methods=['POST'])
@login_required
def toggle_like(post_id):
    user_id = session['user_id']
    conn = get_db_connection()
    if not conn:
        return jsonify({'success': False, 'message': '数据库连接失败。'}), 500
    
    cursor = conn.cursor()
    try:
        cursor.execute("SELECT * FROM likes WHERE user_id_like = %s AND post_id_liked = %s", (user_id, post_id))
        like = cursor.fetchone()

        if like: # User already liked, so unlike
            cursor.execute("DELETE FROM likes WHERE user_id_like = %s AND post_id_liked = %s", (user_id, post_id))
            cursor.execute("UPDATE post SET number_likes = GREATEST(0, number_likes - 1) WHERE post_id = %s", (post_id,))
            liked = False
        else: # User has not liked, so like
            cursor.execute("INSERT INTO likes (user_id_like, post_id_liked) VALUES (%s, %s)", (user_id, post_id))
            cursor.execute("UPDATE post SET number_likes = number_likes + 1 WHERE post_id = %s", (post_id,))
            liked = True
        
        conn.commit()
        
        cursor.execute("SELECT number_likes FROM post WHERE post_id = %s", (post_id,))
        new_likes_count = cursor.fetchone()[0]
        
        return jsonify({'success': True, 'liked': liked, 'likes_count': new_likes_count})
    except mysql.connector.Error as err:
        app.logger.error(f"Toggle like error: {err}")
        return jsonify({'success': False, 'message': str(err)}), 500
    finally:
        cursor.close()
        conn.close()

@app.route('/submit_report/<post_id>', methods=['POST'])
@login_required
def submit_report(post_id):
    reason = request.form['report_reason']
    if not reason.strip():
        return jsonify({'success': False, 'message': '举报原因不能为空。'}), 400 # Bad request

    report_id = f"REP{str(uuid.uuid4().int)[:12]}"
    reporter_id = session['user_id']
    report_status = 1 # 1 for '待处理' (pending)

    conn = get_db_connection()
    if not conn:
        return jsonify({'success': False, 'message': '数据库连接失败。'}), 500
    
    cursor = conn.cursor()
    try:
        # Check if this user already reported this post and it's pending
        cursor.execute("SELECT report_id FROM report WHERE reported_post_id = %s AND reporter_id = %s AND report_status = 1", (post_id, reporter_id))
        if cursor.fetchone():
             return jsonify({'success': False, 'message': '您已举报过此帖子，正在等待处理。'}), 409 # Conflict
        
        cursor.execute(
            "INSERT INTO report (report_id, reporter_id, report_reason, reported_post_id, report_status) VALUES (%s, %s, %s, %s, %s)",
            (report_id, reporter_id, reason, post_id, report_status)
        )
        conn.commit()
        return jsonify({'success': True, 'message': '举报已提交，感谢您的反馈。'})
    except mysql.connector.Error as err:
        app.logger.error(f"Submit report error: {err}")
        return jsonify({'success': False, 'message': str(err)}), 500
    finally:
        cursor.close()
        conn.close()

@app.route('/get_report_history/<post_id>', methods=['GET'])
@login_required
def get_report_history(post_id):
    # For simplicity, this example shows reports by the current user for this post.
    # You might want to show all reports if the user is an admin.
    reporter_id = session['user_id'] 
    conn = get_db_connection()
    if not conn:
        return jsonify({'success': False, 'message': '数据库连接失败。'}), 500

    cursor = conn.cursor(dictionary=True)
    try:
        # Fetch reports made by the current user for this specific post
        # If you want to show all reports for admins, adjust the query and add role check
        cursor.execute(
            "SELECT report_reason, report_status FROM report WHERE reported_post_id = %s AND reporter_id = %s ORDER BY report_id DESC", # Assuming report_id implies time
            (post_id, reporter_id) 
        )
        reports = cursor.fetchall()
        # Convert status to text
        status_map = {0: "已驳回", 1: "审核中", 2: "已处理"}
        for report in reports:
            report['status_text'] = status_map.get(report['report_status'], "未知")
        return jsonify({'success': True, 'reports': reports})
    except mysql.connector.Error as err:
        app.logger.error(f"Get report history error: {err}")
        return jsonify({'success': False, 'message': str(err)}), 500
    finally:
        cursor.close()
        conn.close()


# Context processor to make avatar_url available to all templates
@app.context_processor
def inject_user_avatar():
    avatar_url = None
    if 'user_id' in session and 'user_name' in session:
        # Try to get from session first for efficiency
        if 'avatar_url' in session and session['avatar_url']:
            avatar_url = url_for('static', filename=session['avatar_url'])
        else:
            # Fallback to fetch/generate if not in session or null
            db_avatar_path = get_user_avatar(session['user_id'], session['user_name'])
            if db_avatar_path: # get_user_avatar returns full path from static
                avatar_url = db_avatar_path
            session['avatar_url'] = db_avatar_path.replace(url_for('static', filename=''),'',1) if db_avatar_path else None


    return dict(current_user_avatar_url=avatar_url)


if __name__ == '__main__':
    # Ensure the avatar directory exists
    if not os.path.exists(AVATAR_DIR):
        os.makedirs(AVATAR_DIR)
    app.run(debug=True)
# USTC_DB_HW
## 数据库准备工作
首先在MySQL中创建一个名为community_database的模式（schema），然后逐句运行database_design.sql。
注意管理员信息是通过MySQL直接添加的。
## 前端准备工作
首先修改app.py中关于数据库的信息，改为个人的数据库。
```
import os
# ...
import datetime

app = Flask(__name__)
app.secret_key = 'your_fixed_secret_key_for_development_v3' # 确保使用固定密钥

# --- Database Configuration ---
### 修改此处
DB_CONFIG = {
    'host': 'localhost',
    'user': 'root',
    'password': '1111',
    'database': 'community_database',#对应数据库创建的模式schema 
    'autocommit': True # 确保DML操作立即生效
}
```

然后参考下面指令在VSCode自带的终端内执行下面的操作。
```
# 创建虚拟环境
conda create --name db_hw python=3.10
# 激活虚拟环境
conda activate db_hw
# 下载外部库
pip install Flask mysql-connector-python Pillow Werkzeug
# 运行app.py进入社区网页
python app.py
```

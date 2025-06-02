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
    'password': '123456',
    'database': 'community_database',
    'autocommit': True # 确保DML操作立即生效
}
```


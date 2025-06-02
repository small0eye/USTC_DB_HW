import uuid # For generating user_id
import mysql.connector # Import MySQL connector

class RegistrationWindow:
    def __init__(self, db_connection):
        self.db_connection = db_connection
        # self.window = ... # Initialize your UI window
        # self.window = tk.Toplevel() # Example for Tkinter if LoginWindow is main
        # self.window.title("Register Account")
        print("Initializing Registration Window")
        self.uploaded_avatar_path = None # Initialize path
        self._setup_ui()

    def _setup_ui(self):
        # Username input
        # self.username_input = ...
        # self.username_entry = tk.Entry(self.window)
        # self.username_entry.pack()
        print("  Creating username input")

        # Password input
        # self.password_input = ...
        # self.password_entry = tk.Entry(self.window, show="*")
        # self.password_entry.pack()
        print("  Creating password input")

        # Confirm password input
        # self.confirm_password_input = ...
        # self.confirm_password_entry = tk.Entry(self.window, show="*")
        # self.confirm_password_entry.pack()
        print("  Creating confirm password input")

        # Avatar upload area
        # self.avatar_upload_area = ... # Support drag/drop or click
        # self.avatar_upload_button = tk.Button(self.window, text="Upload Avatar", command=self.handle_avatar_upload_dialog)
        # self.avatar_upload_button.pack()
        # self.avatar_preview = ... # To show uploaded avatar
        # self.avatar_label = tk.Label(self.window, text="No avatar selected")
        # self.avatar_label.pack()
        print("  Creating avatar upload area with preview")

        # Register button
        # self.register_button = ...
        # self.register_button = tk.Button(self.window, text="Register", command=self.handle_registration)
        # self.register_button.pack()
        # self.register_button.config(command=self.handle_registration)
        print("  Creating register button")

        # Back to login button
        # self.back_to_login_button = ...
        # self.back_to_login_button = tk.Button(self.window, text="Back to Login", command=self.go_to_login)
        # self.back_to_login_button.pack()
        # self.back_to_login_button.config(command=self.go_to_login)
        print("  Creating back to login button")

    def handle_avatar_upload_dialog(self):
        # Example using Tkinter's filedialog
        # from tkinter import filedialog
        # file_path = filedialog.askopenfilename(title="Select Avatar Image", filetypes=[("Image Files", "*.png *.jpg *.jpeg *.gif")])
        # if file_path:
        #     self.handle_avatar_upload(file_path)
        pass

    def handle_avatar_upload(self, file_path):
        # Logic to handle file upload and update self.avatar_preview
        # Store or process the avatar image
        print(f"Avatar selected: {file_path}. Displaying preview.")
        self.uploaded_avatar_path = file_path # Store the path
        # Update UI to show preview, e.g., self.avatar_label.config(text=file_path.split('/')[-1])
        # For actual image display, you'd use PIL/Pillow with Tkinter
        pass


    def handle_registration(self):
        username = "" # Get from self.username_input (e.g., self.username_entry.get())
        password = "" # Get from self.password_input (e.g., self.password_entry.get())
        confirm_password = "" # Get from self.confirm_password_input (e.g., self.confirm_password_entry.get())


        if password != confirm_password:
            print("Registration failed: Passwords do not match.")
            # Show error message (e.g., messagebox.showerror("Registration Failed", "Passwords do not match."))
            return

        if not username or not password:
            print("Registration failed: Username and password cannot be empty.")
            # Show error message (e.g., messagebox.showerror("Registration Failed", "Username and password cannot be empty."))
            return

        print(f"Attempting registration for user: {username}")
        # Generate a unique user_id. CHAR(15)
        user_id = f"USER{str(uuid.uuid4().int)[:11]}" 
        user_role = "user"
        # IMPORTANT: In a real application, passwords MUST be hashed before storing.
        
        try:
            cursor = self.db_connection.cursor()
            # Check if username already exists
            check_query = "SELECT user_name FROM user WHERE user_name = %s"
            cursor.execute(check_query, (username,))
            if cursor.fetchone():
                print(f"Registration failed: Username '{username}' already exists.")
                # Show error message (e.g., messagebox.showerror("Registration Failed", f"Username '{username}' already exists."))
                cursor.close()
                return

            query = "INSERT INTO user (user_id, user_name, user_password, user_role) VALUES (%s, %s, %s, %s)"
            cursor.execute(query, (user_id, username, password, user_role))
            self.db_connection.commit()
            print("Registration successful.")
            
            # Here you might want to save self.uploaded_avatar_path linked to user_id
            # For example, in a separate table or by updating the user table if it has an avatar column.
            # if self.uploaded_avatar_path:
            #     print(f"Avatar path to save for {user_id}: {self.uploaded_avatar_path}")
            #     # Add logic to save avatar path to DB or copy file to a designated avatars folder

            # Show success message (e.g., messagebox.showinfo("Registration Successful", "Account created successfully! Please login."))
            self.go_to_login()
        except mysql.connector.Error as err:
            print(f"Registration failed due to database error: {err}")
            # Show error message (e.g., messagebox.showerror("Registration Failed", f"Database error: {err}"))
            if self.db_connection.is_connected(): # Rollback if commit failed partially or error occurred before commit
                self.db_connection.rollback()
        except Exception as e:
            print(f"An unexpected error occurred during registration: {e}")
            # Show error message
        finally:
            if 'cursor' in locals() and cursor:
                cursor.close()
        pass


    def go_to_login(self):
        print("Navigating back to Login Window")
        # self.window.destroy() # Close current registration window - UI specific
        from login_ui import LoginWindow # Import here
        # If LoginWindow expects the main Tkinter root, you might need to manage that (e.g., pass it or re-create)
        # For now, assuming LoginWindow can create its own top-level window or is managed by app.py
        login_window = LoginWindow(self.db_connection)
        login_window.show()
        pass

    def show(self):
        # self.window.mainloop() # Or similar method to show/run the UI
        print("Displaying Registration Window")

if __name__ == '__main__':
    # import mysql.connector
    # try:
    #     db_conn = mysql.connector.connect(
    #         host="localhost",
    #         user="your_db_user",
    #         password="your_db_password",
    #         database="community_database"
    #     )
    #     print("Database connected successfully for RegistrationWindow direct run.")
    #     # root = tk.Tk() # Main window for Tkinter
    #     # registration_app = RegistrationWindow(db_conn, root) # Pass root if needed
    #     registration_app = RegistrationWindow(db_conn)
    #     registration_app.show()
    #     # root.mainloop()
    # except mysql.connector.Error as err:
    #     print(f"Failed to connect to database: {err}")
    # finally:
    #     if 'db_conn' in locals() and db_conn.is_connected():
    #         db_conn.close()
    #         print("Database connection closed.")
    print("Registration UI conceptual structure.")

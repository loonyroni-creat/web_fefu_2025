from django.contrib.auth.backends import ModelBackend
from django.contrib.auth.models import User
from django.db.models import Q

class EmailBackend(ModelBackend):
    """
    Кастомный бэкенд аутентификации для входа по email вместо username
    """
    
    def authenticate(self, request, username=None, password=None, **kwargs):
        """
        Аутентификация пользователя по email и паролю
        """
        try:
            # Ищем пользователя по email или username
            user = User.objects.get(
                Q(email=username) | Q(username=username)
            )
        except User.DoesNotExist:
            return None
        
        # Проверяем пароль
        if user.check_password(password):
            return user
        return None
    
    def get_user(self, user_id):
        """
        Получение пользователя по ID
        """
        try:
            return User.objects.get(pk=user_id)
        except User.DoesNotExist:
            return None
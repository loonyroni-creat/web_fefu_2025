from django.db import models

class UserProfile(models.Model):
    username = models.CharField(max_length=50, unique=True, verbose_name='Логин')
    email = models.EmailField(unique=True, verbose_name='Email')
    password = models.CharField(max_length=128, verbose_name='Пароль')
    created_at = models.DateTimeField(auto_now_add=True, verbose_name='Дата регистрации')

    def __str__(self):
        return self.username

# Create your models here.

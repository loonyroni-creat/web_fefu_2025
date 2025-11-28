from django import forms
from django.core.exceptions import ValidationError
from .models import UserProfile
from django.contrib.auth.models import User
from django.contrib.auth.forms import UserCreationForm
from .models import Student

class FeedbackForm(forms.Form):
    """Форма обратной связи"""
    name = forms.CharField(
        max_length=100,
        label='Имя',
        widget=forms.TextInput(attrs={'class': 'form-control'})
    )
    email = forms.EmailField(
        label='Email', 
        widget=forms.EmailInput(attrs={'class': 'form-control'})
    )
    subject = forms.CharField(
        max_length=200,
        label='Тема сообщения',
        widget=forms.TextInput(attrs={'class': 'form-control'})
    )
    message = forms.CharField(
        label='Текст сообщения',
        widget=forms.Textarea(attrs={'class': 'form-control', 'rows': 4})
    )

    def clean_name(self):
        name = self.cleaned_data['name']
        if len(name.strip()) < 2:
            raise ValidationError("Имя должно содержать минимум 2 символа")
        return name.strip()

    def clean_message(self):
        message = self.cleaned_data['message']
        if len(message.strip()) < 10:
            raise ValidationError("Сообщение должно содержать минимум 10 символов")
        return message.strip()

class RegistrationForm(forms.Form):
    """Форма регистрации пользователя"""
    username = forms.CharField(
        max_length=50,
        label='Логин',
        widget=forms.TextInput(attrs={'class': 'form-control'})
    )
    email = forms.EmailField(
        label='Email',
        widget=forms.EmailInput(attrs={'class': 'form-control'})
    )
    password = forms.CharField(
        label='Пароль', 
        widget=forms.PasswordInput(attrs={'class': 'form-control'})
    )
    password_confirm = forms.CharField(
        label='Подтверждение пароля',
        widget=forms.PasswordInput(attrs={'class': 'form-control'})
    )

    def clean_username(self):
        username = self.cleaned_data['username']
        if len(username) < 3:
            raise ValidationError("Логин должен содержать минимум 3 символа")
        if User.objects.filter(username=username).exists():  # Исправлено: User вместо UserProfile
            raise ValidationError("Пользователь с таким логином уже существует")
        return username

    def clean(self):
        cleaned_data = super().clean()
        password = cleaned_data.get('password')
        password_confirm = cleaned_data.get('password_confirm')
        
        if password and password_confirm and password != password_confirm:
            raise ValidationError("Пароли не совпадают")
        
        return cleaned_data

# ДОБАВЛЯЕМ НОВУЮ ФОРМУ
class UserRegistrationForm(UserCreationForm):
    """
    Форма регистрации пользователя с дополнительными полями
    """
    email = forms.EmailField(
        required=True,
        label='Email',
        widget=forms.EmailInput(attrs={'class': 'form-control'})
    )
    first_name = forms.CharField(
        required=True,
        label='Имя',
        widget=forms.TextInput(attrs={'class': 'form-control'})
    )
    last_name = forms.CharField(
        required=True,
        label='Фамилия',
        widget=forms.TextInput(attrs={'class': 'form-control'})
    )
    faculty = forms.ChoiceField(
        choices=Student.FACULTY_CHOICES,
        label='Факультет',
        widget=forms.Select(attrs={'class': 'form-control'})
    )
    phone = forms.CharField(
        required=False,
        label='Телефон',
        widget=forms.TextInput(attrs={'class': 'form-control'})
    )
    bio = forms.CharField(
        required=False,
        label='О себе',
        widget=forms.Textarea(attrs={'class': 'form-control', 'rows': 4})
    )

    class Meta:
        model = User
        fields = ['username', 'email', 'first_name', 'last_name', 'password1', 'password2']
        widgets = {
            'username': forms.TextInput(attrs={'class': 'form-control'}),
        }

    def clean_email(self):
        """
        Проверка уникальности email
        """
        email = self.cleaned_data.get('email')
        if User.objects.filter(email=email).exists():
            raise ValidationError('Пользователь с таким email уже существует')
        return email

    def save(self, commit=True):
        """
        Сохранение пользователя и создание профиля
        """
        user = super().save(commit=False)
        user.email = self.cleaned_data['email']
        user.first_name = self.cleaned_data['first_name']
        user.last_name = self.cleaned_data['last_name']
        
        if commit:
            user.save()
            # Создаем или обновляем профиль студента
            profile, created = Student.objects.get_or_create(
                user=user,
                defaults={
                    'faculty': self.cleaned_data['faculty'],
                    'phone': self.cleaned_data['phone'],
                    'bio': self.cleaned_data['bio'],
                    'role': 'STUDENT'
                }
            )
            
            # Если профиль уже существовал, обновляем его
            if not created:
                profile.faculty = self.cleaned_data['faculty']
                profile.phone = self.cleaned_data['phone']
                profile.bio = self.cleaned_data['bio']
                profile.save()
        
        return user

class UserLoginForm(forms.Form):
    """
    Форма входа пользователя
    """
    username = forms.CharField(
        label='Email или имя пользователя',
        widget=forms.TextInput(attrs={'class': 'form-control'})
    )
    password = forms.CharField(
        label='Пароль',
        widget=forms.PasswordInput(attrs={'class': 'form-control'})
    )

class UserProfileForm(forms.ModelForm):
    """
    Форма редактирования профиля пользователя
    """
    class Meta:
        model = User
        fields = ['first_name', 'last_name', 'email']
        widgets = {
            'first_name': forms.TextInput(attrs={'class': 'form-control'}),
            'last_name': forms.TextInput(attrs={'class': 'form-control'}),
            'email': forms.EmailInput(attrs={'class': 'form-control'}),
        }

class StudentProfileForm(forms.ModelForm):
    """
    Форма редактирования профиля студента
    """
    class Meta:
        model = Student
        fields = ['faculty', 'phone', 'bio', 'birth_date', 'avatar']
        widgets = {
            'faculty': forms.Select(attrs={'class': 'form-control'}),
            'phone': forms.TextInput(attrs={'class': 'form-control'}),
            'bio': forms.Textarea(attrs={'class': 'form-control', 'rows': 4}),
            'birth_date': forms.DateInput(attrs={'class': 'form-control', 'type': 'date'}),
        }
from django.shortcuts import render, get_object_or_404
from django.http import Http404
from django.views.generic import View, DetailView, ListView
from django.contrib.auth import login, logout, authenticate
from django.contrib.auth.decorators import login_required, user_passes_test
from django.contrib.auth.models import User
from django.contrib import messages
from django.shortcuts import redirect

from .models import Student, Course, Instructor, Enrollment
from .forms import FeedbackForm, RegistrationForm, UserRegistrationForm, UserLoginForm, UserProfileForm, StudentProfileForm

# СУЩЕСТВУЮЩИЕ ПРЕДСТАВЛЕНИЯ (ОБНОВЛЕННЫЕ)
def home_page(request):
    total_students = Student.objects.filter(is_active=True).count()
    total_courses = Course.objects.filter(is_active=True).count()
    total_instructors = Instructor.objects.filter(is_active=True).count()
    recent_courses = Course.objects.filter(is_active=True).select_related('instructor').order_by('-created_at')[:3]
    
    return render(request, 'fefu_lab/home.html', {
        'title': 'Главная страница',
        'total_students': total_students,
        'total_courses': total_courses,
        'total_instructors': total_instructors,
        'recent_courses': recent_courses
    })

def about_page(request):
    return render(request, 'fefu_lab/about.html', {
        'title': 'О нас'
    })

class StudentDetailView(DetailView):
    model = Student
    template_name = 'fefu_lab/student_profile.html'
    context_object_name = 'student'
    
    def get_context_data(self, **kwargs):
        context = super().get_context_data(**kwargs)
        context['enrollments'] = Enrollment.objects.filter(
            student=self.object, 
            status='ACTIVE'
        ).select_related('course')
        return context
    
class CourseDetailView(DetailView):
    model = Course
    template_name = 'fefu_lab/course_detail.html'
    context_object_name = 'course'
    slug_field = 'slug'
    slug_url_kwarg = 'course_slug'
    
    def get_context_data(self, **kwargs):
        context = super().get_context_data(**kwargs)
        context['enrollments'] = Enrollment.objects.filter(
            course=self.object, 
            status='ACTIVE'
        ).select_related('student')
        return context

def feedback_view(request):
    if request.method == 'POST':
        form = FeedbackForm(request.POST)
        if form.is_valid():
            return render(request, 'fefu_lab/success.html', {
                'message': 'Ваше сообщение успешно отправлено!',
                'title': 'Обратная связь'
            })
    else:
        form = FeedbackForm()
    
    return render(request, 'fefu_lab/feedback.html', {
        'form': form,
        'title': 'Обратная связь'
    })

def old_register_view(request):
    if request.method == 'POST':
        form = RegistrationForm(request.POST)
        if form.is_valid():
            return render(request, 'fefu_lab/success.html', {
                'message': f'Пользователь успешно зарегистрирован!',
                'title': 'Регистрация'
            })
    else:
        form = RegistrationForm()
    
    return render(request, 'fefu_lab/register.html', {
        'form': form,
        'title': 'Регистрация'
    })

class StudentListView(ListView):
    model = Student
    template_name = 'fefu_lab/student_list.html'
    context_object_name = 'students'
    paginate_by = 10
    
    def get_queryset(self):
        return Student.objects.filter(is_active=True).select_related('user')

class CourseListView(ListView):
    model = Course
    template_name = 'fefu_lab/course_list.html'
    context_object_name = 'courses'
    paginate_by = 9
    
    def get_queryset(self):
        return Course.objects.filter(is_active=True).select_related('instructor')

# Декораторы для проверки ролей
def student_required(function=None):
    actual_decorator = user_passes_test(
        lambda u: hasattr(u, 'student_profile') and u.student_profile.role in ['STUDENT', 'ADMIN'],
        login_url='/login/'
    )
    if function:
        return actual_decorator(function)
    return actual_decorator

def teacher_required(function=None):
    actual_decorator = user_passes_test(
        lambda u: hasattr(u, 'student_profile') and u.student_profile.role in ['TEACHER', 'ADMIN'],
        login_url='/login/'
    )
    if function:
        return actual_decorator(function)
    return actual_decorator

def admin_required(function=None):
    actual_decorator = user_passes_test(
        lambda u: hasattr(u, 'student_profile') and u.student_profile.role == 'ADMIN',
        login_url='/login/'
    )
    if function:
        return actual_decorator(function)
    return actual_decorator

def register_view(request):
    if request.method == 'POST':
        form = UserRegistrationForm(request.POST)
        if form.is_valid():
            user = form.save()
            
            authenticated_user = authenticate(
                request,
                username=form.cleaned_data['username'],
                password=form.cleaned_data['password1']
            )
            
            if authenticated_user is not None:
                login(request, authenticated_user)
                messages.success(request, f'Регистрация прошла успешно! Добро пожаловать, {user.first_name}!')
                return redirect('profile')
            else:
                messages.success(request, f'Регистрация прошла успешно! Добро пожаловать, {user.first_name}!')
                messages.info(request, 'Пожалуйста, войдите в систему со своими учетными данными.')
                return redirect('login')
                
    else:
        form = UserRegistrationForm()
    
    return render(request, 'fefu_lab/registration/register.html', {
        'form': form,
        'title': 'Регистрация'
    })

def login_view(request):
    if request.method == 'POST':
        form = UserLoginForm(request.POST)
        if form.is_valid():
            username = form.cleaned_data['username']
            password = form.cleaned_data['password']
            user = authenticate(request, username=username, password=password)
            
            if user is not None:
                login(request, user)
                messages.success(request, f'Добро пожаловать, {user.first_name}!')
                next_url = request.GET.get('next', 'profile')
                return redirect(next_url)
            else:
                messages.error(request, 'Неверный email или пароль')
    else:
        form = UserLoginForm()
    
    return render(request, 'fefu_lab/registration/login.html', {
        'form': form,
        'title': 'Вход в систему'
    })

def logout_view(request):
    logout(request)
    messages.success(request, 'Вы успешно вышли из системы')
    return redirect('home')

@login_required
def profile_view(request):
    if request.method == 'POST':
        user_form = UserProfileForm(request.POST, instance=request.user)
        profile_form = StudentProfileForm(
            request.POST, 
            request.FILES, 
            instance=request.user.student_profile
        )
        
        if user_form.is_valid() and profile_form.is_valid():
            user_form.save()
            profile_form.save()
            messages.success(request, 'Профиль успешно обновлен')
            return redirect('profile')
    else:
        user_form = UserProfileForm(instance=request.user)
        profile_form = StudentProfileForm(instance=request.user.student_profile)
    
    return render(request, 'fefu_lab/registration/profile.html', {
        'user_form': user_form,
        'profile_form': profile_form,
        'title': 'Мой профиль'
    })

# Личные кабинеты
@login_required
@student_required
def student_dashboard(request):
    student = request.user.student_profile
    enrollments = Enrollment.objects.filter(student=student, status='ACTIVE').select_related('course')
    
    return render(request, 'fefu_lab/dashboard/student_dashboard.html', {
        'student': student,
        'enrollments': enrollments,
        'title': 'Личный кабинет студента'
    })

@login_required
@teacher_required
def teacher_dashboard(request):
    """
    Личный кабинет преподавателя - ИСПРАВЛЕННАЯ ВЕРСИЯ
    """
    teacher_profile = request.user.student_profile
    
    # Ищем курсы, где преподаватель - это любой активный Instructor
    # Для тестирования берем первый попавшийся курс
    courses = Course.objects.filter(is_active=True)[:2]  # Временно показываем любые 2 курса
    
    # Статистика по курсам
    course_stats = []
    for course in courses:
        enrollments_count = Enrollment.objects.filter(course=course, status='ACTIVE').count()
        course_stats.append({
            'course': course,
            'students_count': enrollments_count,
            'available_seats': course.available_slots()
        })
    
    return render(request, 'fefu_lab/dashboard/teacher_dashboard.html', {
        'teacher': teacher_profile,
        'course_stats': course_stats,
        'title': 'Личный кабинет преподавателя'
    })

@login_required
@admin_required
def admin_dashboard(request):
    stats = {
        'total_students': Student.objects.filter(role='STUDENT', is_active=True).count(),
        'total_teachers': Student.objects.filter(role='TEACHER', is_active=True).count(),
        'total_courses': Course.objects.filter(is_active=True).count(),
        'total_enrollments': Enrollment.objects.filter(status='ACTIVE').count(),
    }
    
    return render(request, 'fefu_lab/dashboard/admin_dashboard.html', {
        'stats': stats,
        'title': 'Панель администратора'
    })

@login_required
def dashboard_view(request):
    profile = request.user.student_profile
    
    if profile.role == 'ADMIN':
        return redirect('admin_dashboard')
    elif profile.role == 'TEACHER':
        return redirect('teacher_dashboard')
    else:
        return redirect('student_dashboard')
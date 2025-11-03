from django.shortcuts import render, get_object_or_404
from django.http import Http404
from django.views.generic import View, ListView, DetailView
from .models import Student, Course, Instructor, Enrollment
from .forms import FeedbackForm, RegistrationForm


# СУЩЕСТВУЮЩИЕ ПРЕДСТАВЛЕНИЯ (ОБНОВЛЕННЫЕ)
def home_page(request):
    # Получаем реальные данные из БД
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
    return render(request, 'fefu_lab/about.html')

class StudentDetailView(DetailView):
    model = Student
    template_name = 'fefu_lab/student_profile.html'
    context_object_name = 'student'
    
    def get_context_data(self, **kwargs):
        context = super().get_context_data(**kwargs)
        # Добавляем связанные записи на курсы
        context['enrollments'] = self.object.enrollments.select_related('course').filter(status='ACTIVE')
        return context
    
class CourseDetailView(DetailView):
    model = Course
    template_name = 'fefu_lab/course_detail.html'
    context_object_name = 'course'
    slug_field = 'slug'
    slug_url_kwarg = 'course_slug'
    
    def get_context_data(self, **kwargs):
        context = super().get_context_data(**kwargs)
        # Добавляем список студентов записанных на курс
        context['enrollments'] = self.object.enrollments.select_related('student').filter(status='ACTIVE')
        return context

# НОВЫЕ ПРЕДСТАВЛЕНИЯ ДЛЯ ФОРМ
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

def register_view(request):
    if request.method == 'POST':
        form = RegistrationForm(request.POST)
        if form.is_valid():
            user = UserProfile(
                username=form.cleaned_data['username'],
                email=form.cleaned_data['email'],
                password=form.cleaned_data['password']
            )
            user.save()
            
            return render(request, 'fefu_lab/success.html', {
                'message': f'Пользователь {user.username} успешно зарегистрирован!',
                'title': 'Регистрация'
            })
    else:
        form = RegistrationForm()
    
    return render(request, 'fefu_lab/register.html', {
        'form': form,
        'title': 'Регистрация'
    })
# Добавляем новые представления для списков
class StudentListView(ListView):
    model = Student
    template_name = 'fefu_lab/student_list.html'
    context_object_name = 'students'
    paginate_by = 10
    
    def get_queryset(self):
        return Student.objects.filter(is_active=True).select_related()

class CourseListView(ListView):
    model = Course
    template_name = 'fefu_lab/course_list.html'
    context_object_name = 'courses'
    paginate_by = 9
    
    def get_queryset(self):
        return Course.objects.filter(is_active=True).select_related('instructor')
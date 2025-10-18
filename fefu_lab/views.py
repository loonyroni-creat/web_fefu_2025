from django.shortcuts import render
from django.http import HttpResponse
from django.http import Http404
from django.views.generic import View

class CourseDetailView(View):
    def get(self, request, course_slug):
        courses_data = {
            'python-basic': {
                'title': 'Python Basic', 
                'description': 'Базовый курс программирования на Python'
            },
            'django-advanced': {
                'title': 'Django Advanced', 
                'description': 'Продвинутый курс веб-разработки на Django'
            }
        }
        
        course = courses_data.get(course_slug)
        if not course:
            raise Http404("Курс не найден.")
        
        html = f"""
        <!DOCTYPE html>
        <html>
        <head>
            <title>{course['title']}</title>
        </head>
        <body>
            <h1>Информация о курсе</h1>
            <p><strong>Slug:</strong> {course_slug}</p>
            <p><strong>Название:</strong> {course['title']}</p>
            <p><strong>Описание:</strong> {course['description']}</p>
            <a href="/">Вернуться на главную</a>
        </body>
        </html>
        """
        return HttpResponse(html)
def home_page(request):
    html = """
    <!DOCTYPE html>
    <html>
    <head>
        <title>Главная страница</title>
    </head>
    <body>
        <h1>Добро пожаловать на главную страницу!</h1>
        <p>Это главная страница нашего сайта.</p>
        <ul>
            <li><a href="/about/">О нас</a></li>
            <li><a href="/student/1/">Профиль студента 1</a></li>
            <li><a href="/student/2/">Профиль студента 2</a></li>
            <li><a href="/course/python-basic/">Курс Python Basic</a></li>
            <li><a href="/course/django-advanced/">Курс Django Advanced</a></li>
        </ul>
    </body>
    </html>
    """
    return HttpResponse(html)

def about_page(request):
    html = """
    <!DOCTYPE html>
    <html>
    <head>
        <title>О нас</title>
    </head>
    <body>
        <h1>О нас</h1>
        <p>Это страница о нашем проекте и команде.</p>
        <p>Мы изучаем Django и веб-разработку!</p>
        <a href="/">Вернуться на главную</a>
    </body>
    </html>
    """
    return HttpResponse(html)
def student_profile(request, student_id):
    if student_id > 100:
        raise Http404("Студент с таким ID не найден.")
    
    students_data = {
        1: {"name": "Иван Иванов", "group": "БПМ-21-1"},
        2: {"name": "Мария Петрова", "group": "БПМ-21-2"},
        3: {"name": "Алексей Сидоров", "group": "БПМ-21-1"}
    }
    
    student = students_data.get(student_id)
    if not student:
        raise Http404("Студент с таким ID не найден.")
    
    html = f"""
    <!DOCTYPE html>
    <html>
    <head>
        <title>Профиль студента</title>
    </head>
    <body>
        <h1>Профиль студента</h1>
        <p><strong>ID:</strong> {student_id}</p>
        <p><strong>Имя:</strong> {student['name']}</p>
        <p><strong>Группа:</strong> {student['group']}</p>
        <a href="/">Вернуться на главную</a>
    </body>
    </html>
    """
    return HttpResponse(html)

# Create your views here.

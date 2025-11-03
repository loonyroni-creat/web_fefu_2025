from django.urls import path
from . import views

urlpatterns = [
    # Основные страницы
    path('', views.home_page, name='home'),
    path('about/', views.about_page, name='about'),
    
    # Студенты
    path('students/', views.StudentListView.as_view(), name='student_list'),
    path('student/<int:pk>/', views.StudentDetailView.as_view(), name='student_detail'),
    
    # Курсы
    path('courses/', views.CourseListView.as_view(), name='course_list'),
    path('course/<slug:course_slug>/', views.CourseDetailView.as_view(), name='course_detail'),
    
    # Формы
    path('feedback/', views.feedback_view, name='feedback'),
    path('register/', views.register_view, name='register'),
]
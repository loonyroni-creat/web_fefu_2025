from django.urls import path
from . import views

urlpatterns = [
    # СТАРЫЕ МАРШРУТЫ
    path('', views.home_page, name='home'),
    path('about/', views.about_page, name='about'),
    path('student/<int:student_id>/', views.student_profile, name='student_profile'),
    path('course/<slug:course_slug>/', views.CourseDetailView.as_view(), name='course_detail'),
    
    # НОВЫЕ МАРШРУТЫ ДЛЯ ФОРМ
    path('feedback/', views.feedback_view, name='feedback'),
    path('register/', views.register_view, name='register'),
]
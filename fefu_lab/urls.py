from django.urls import path
from . import views
from django.conf import settings
from django.conf.urls.static import static

urlpatterns = [
    # Основные страницы
    path('', views.home_page, name='home'),
    path('about/', views.about_page, name='about'),
    path('students/', views.student_list, name='student_list'),
    path('student/<int:student_id>/', views.student_profile, name='student_profile'),
    path('courses/', views.course_list, name='course_list'),
    path('course/<slug:course_slug>/', views.CourseDetailView.as_view(), name='course_detail'),
    path('feedback/', views.feedback_view, name='feedback'),
    
    # Аутентификация
    path('register/', views.register_view, name='register'),
    path('login/', views.login_view, name='login'),
    path('logout/', views.logout_view, name='logout'),
    path('profile/', views.profile_view, name='profile'),
    
    # Личные кабинеты
    path('dashboard/', views.dashboard_view, name='dashboard'),
    path('dashboard/student/', views.student_dashboard, name='student_dashboard'),
    path('dashboard/teacher/', views.teacher_dashboard, name='teacher_dashboard'),
    path('dashboard/admin/', views.admin_dashboard, name='admin_dashboard'),
]

# Добавляем маршруты для медиа-файлов в режиме разработки
if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
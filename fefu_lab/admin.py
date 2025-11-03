from django.contrib import admin
from .models import Instructor, Student, Course, Enrollment

@admin.register(Student)
class StudentAdmin(admin.ModelAdmin):
    list_display = ['last_name', 'first_name', 'email', 'faculty', 'is_active']
    list_filter = ['is_active', 'faculty']
    search_fields = ['first_name', 'last_name', 'email']
    list_per_page = 20

@admin.register(Course)
class CourseAdmin(admin.ModelAdmin):
    list_display = ['title', 'instructor', 'level', 'duration', 'price', 'is_active']
    list_filter = ['is_active', 'level', 'instructor']
    search_fields = ['title', 'description']
    prepopulated_fields = {'slug': ['title']}
# Register your models here.

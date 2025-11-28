from django.contrib import admin
from .models import Instructor, Student, Course, Enrollment

@admin.register(Student)
class StudentAdmin(admin.ModelAdmin):
    list_display = ['get_last_name', 'get_first_name', 'get_email', 'role', 'faculty', 'is_active']
    list_filter = ['is_active', 'role', 'faculty', 'created_at']
    search_fields = ['user__first_name', 'user__last_name', 'user__email', 'phone']
    list_per_page = 20
    readonly_fields = ['created_at', 'updated_at']
    
    fieldsets = (
        ('Учетная запись', {
            'fields': ('user', 'role')
        }),
        ('Личная информация', {
            'fields': ('phone', 'avatar', 'bio', 'birth_date')
        }),
        ('Учебная информация', {
            'fields': ('faculty',)
        }),
        ('Системная информация', {
            'fields': ('is_active', 'created_at', 'updated_at')
        }),
    )
    
    def get_last_name(self, obj):
        return obj.user.last_name
    get_last_name.short_description = 'Фамилия'
    get_last_name.admin_order_field = 'user__last_name'
    
    def get_first_name(self, obj):
        return obj.user.first_name
    get_first_name.short_description = 'Имя'
    get_first_name.admin_order_field = 'user__first_name'
    
    def get_email(self, obj):
        return obj.user.email
    get_email.short_description = 'Email'
    get_email.admin_order_field = 'user__email'

@admin.register(Course)
class CourseAdmin(admin.ModelAdmin):
    list_display = ['title', 'instructor', 'level', 'duration', 'price', 'is_active']
    list_filter = ['is_active', 'level', 'instructor']
    search_fields = ['title', 'description']
    prepopulated_fields = {'slug': ['title']}
# Register your models here.

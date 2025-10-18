from django.shortcuts import render
from django.http import HttpResponse
from django.http import Http404

def home_page(request):
    return HttpResponse("Добро пожаловать на главную страницу!")

def about_page(request):
    return HttpResponse("Страница 'О нас'")

def student_profile(request, student_id):
    if student_id > 100:
        raise Http404("Студент не найден")
    return HttpResponse(f"Профиль студента с ID: {student_id}")
# Create your views here.

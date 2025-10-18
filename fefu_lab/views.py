from django.shortcuts import render
from django.http import HttpResponse

def home_page(request):
    return HttpResponse("Добро пожаловать на главную страницу!")

def about_page(request):
    return HttpResponse("Страница 'О нас'")

# Create your views here.

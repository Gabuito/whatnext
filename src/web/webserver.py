#!/usr/bin/env python

import os, sys
import subprocess

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from scheduler import configure_subjects, sort_subjects

from flask import Flask, request, jsonify, Response
from flask_cors import CORS
import json
from detail import get_subject
from nocache import nocache

app = Flask(__name__)
app.debug=True
CORS(app)

SUCCESS_MESSAGE = '{"message": "success"}'

@app.route('/scheduler')
@nocache
def index():
    tiredMode = request.args.get('tiredMode', default = False, type = bool)


    my_env = os.environ.copy()

    if tiredMode:
        my_env["TIRED"] = "1"


    cmd = [
        os.path.dirname(os.path.realpath(__file__)) + '/../scheduler.py',
    ]

    my_env["TO_JSON"] = "1"
    content = subprocess.run(cmd, env=my_env, stdout=subprocess.PIPE).stdout.decode('UTF-8')


    return content, 200, {'Content-Type': 'application/json; charset=utf-8'}

@app.route('/log')
def log():
    cmd = [ os.path.dirname(os.path.realpath(__file__)) + '/../log.sh', '--json']
    content =  subprocess.run(cmd, stdout=subprocess.PIPE).stdout.decode('UTF-8')

    return content, 200, {'Content-Type': 'application/json; charset=utf-8'}

@app.route('/done/<subjectName>', methods = ['POST'])
def done(subjectName):
    data=request.json
    cmd = [
        os.path.dirname(os.path.realpath(__file__)) + '/../done.sh',
        subjectName,
        data['description'],
        data['whatToDoNext']
    ]

    my_env = os.environ.copy()
    my_env["NO_ITERACTIVE"] = "1"
    subprocess.run(cmd, env=my_env, stdout=subprocess.PIPE)

    return SUCCESS_MESSAGE, 200, {'Content-Type': 'application/json; charset=utf-8'}


@app.route('/add', methods = ['POST'])
def add():
    data=request.json
    cmd = [
        os.path.dirname(os.path.realpath(__file__)) + '/../add.sh',
        data['name'],
        str(data['priority']),
        str(data['complexity'])
    ]
    subprocess.run(cmd, stdout=subprocess.PIPE)

    return SUCCESS_MESSAGE, 200, {'Content-Type': 'application/json; charset=utf-8'}

@app.route('/rm/<subjectName>', methods = ['GET'])
def rm(subjectName):
    data=request.json
    cmd = [
        os.path.dirname(os.path.realpath(__file__)) + '/../rm.sh',
        subjectName
    ]
    subprocess.run(cmd, stdout=subprocess.PIPE)

    return SUCCESS_MESSAGE, 200, {'Content-Type': 'application/json; charset=utf-8'}


@app.route('/detail/<subjectName>')
def detail(subjectName):
    obj = get_subject(subjectName)
    result = json.dumps(obj)
    return result, 200, {'Content-Type': 'application/json; charset=utf-8'}




@app.route('/signup', methods = ['POST'])
def signup():
    data=request.json
    cmd = [
        os.path.dirname(os.path.realpath(__file__)) + '/signup.sh',
        data['email'],
        data['password']
    ]

    result = subprocess.run(cmd, stdout=subprocess.PIPE)

    if result.returncode != 0:
        return '{"status": "'+str(result.returncode)+'" "message": "' + result.stdout.decode('UTF-8') + '"}', 200, {'Content-Type': 'application/json; charset=utf-8'}


    return SUCCESS_MESSAGE, 200, {'Content-Type': 'application/json; charset=utf-8'}

app.run(host= '0.0.0.0', port=5000)

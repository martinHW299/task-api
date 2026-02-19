<?php

use App\Http\Controllers\Api\TaskController;
use Illuminate\Support\Facades\Route;

Route::get('/health', function () {
    return response()->json(['status' => 'ok']);
});

Route::apiResource('tasks', TaskController::class);

Route::get('/hello', function () {
    return response()->json(['message' => 'Hello Azure devops!']);
});

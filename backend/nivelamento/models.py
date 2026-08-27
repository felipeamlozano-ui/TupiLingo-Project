from django.db import models
from users.models import UserProfile

class TestAttempt(models.Model):
    user = models.ForeignKey(UserProfile, on_delete=models.CASCADE, related_name="test_attempts")
    timestamp = models.DateTimeField(auto_now_add=True)
    calculated_level = models.IntegerField()
    calculated_theta = models.FloatField(default=0.0)
    is_suspected_cheating = models.BooleanField(default=False)
    
    def __str__(self):
        return f"Attempt by {self.user.name} - Level {self.calculated_level}"

class AnswerItem(models.Model):
    attempt = models.ForeignKey(TestAttempt, on_delete=models.CASCADE, related_name="answers")
    question_hash = models.CharField(max_length=255)
    question_text = models.TextField()
    selected_letter = models.CharField(max_length=1)
    is_correct = models.BooleanField()
    time_taken_seconds = models.FloatField()
    
    param_a = models.FloatField(default=1.2)
    param_b = models.FloatField(default=0.0)
    param_c = models.FloatField(default=0.25)

    def __str__(self):
        return f"Answer for {self.question_hash[:8]} - Correct: {self.is_correct}"

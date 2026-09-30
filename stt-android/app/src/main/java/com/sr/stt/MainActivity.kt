package com.sr.stt

import android.os.Bundle
import androidx.appcompat.app.AppCompatActivity
import com.sr.stt.databinding.ActivityMainBinding

class MainActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val binding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(binding.root)
        binding.status.text = getString(R.string.shell_status)
    }
}

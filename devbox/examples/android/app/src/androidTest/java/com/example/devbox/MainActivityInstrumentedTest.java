package com.example.devbox;

import android.content.Context;
import androidx.test.platform.app.InstrumentationRegistry;
import androidx.test.ext.junit.runners.AndroidJUnit4;
import androidx.test.ext.junit.rules.ActivityScenarioRule;

import org.junit.Test;
import org.junit.Rule;
import org.junit.runner.RunWith;

import static org.junit.Assert.*;

/**
 * Instrumented test, which will execute on an Android device.
 *
 * @see <a href="http://d.android.com/tools/testing">Testing documentation</a>
 */
@RunWith(AndroidJUnit4.class)
public class MainActivityInstrumentedTest {

    @Rule
    public ActivityScenarioRule<MainActivity> activityRule =
        new ActivityScenarioRule<>(MainActivity.class);

    @Test
    public void useAppContext() {
        // Context of the app under test.
        Context appContext = InstrumentationRegistry.getInstrumentation().getTargetContext();
        assertEquals("com.example.devbox", appContext.getPackageName());
    }

    @Test
    public void activityLaunches() {
        // Verify that the activity launches successfully
        activityRule.getScenario().onActivity(activity -> {
            assertNotNull(activity);
            assertNotNull(activity.getWindow());
        });
    }

    @Test
    public void activityHasCorrectLayout() {
        activityRule.getScenario().onActivity(activity -> {
            // Verify the content view is set
            assertNotNull(activity.findViewById(android.R.id.content));
        });
    }
}

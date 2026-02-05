package com.example.devbox;

import org.junit.Test;
import static org.junit.Assert.*;

/**
 * Example local unit test, which will execute on the development machine (host).
 *
 * @see <a href="http://d.android.com/tools/testing">Testing documentation</a>
 */
public class ExampleUnitTest {
    @Test
    public void addition_isCorrect() {
        assertEquals(4, 2 + 2);
    }

    @Test
    public void string_concatenation_works() {
        String result = "Hello" + " " + "World";
        assertEquals("Hello World", result);
    }

    @Test
    public void math_operations_work() {
        assertEquals(10, 5 * 2);
        assertEquals(5, 10 / 2);
        assertEquals(0, 10 % 2);
    }
}

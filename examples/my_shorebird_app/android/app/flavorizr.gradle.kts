import com.android.build.gradle.AppExtension

val android = project.extensions.getByType(AppExtension::class.java)

android.apply {
    flavorDimensions("env")

    productFlavors {
        create("sit") {
            dimension = "env"
            applicationId = "com.example.my_shorebird_app.sit"
            resValue(type = "string", name = "app_name", value = "MyShorebirdApp SIT")
        }
        create("prod") {
            dimension = "env"
            applicationId = "com.example.my_shorebird_app"
            resValue(type = "string", name = "app_name", value = "MyShorebirdApp")
        }
    }
}
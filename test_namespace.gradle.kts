subprojects {
    afterEvaluate {
        val androidExt = extensions.findByName("android")
        if (androidExt != null) {
            val ns = androidExt.javaClass.getMethod("getNamespace").invoke(androidExt)
            println("Project ${project.name} namespace: $ns")
        }
    }
}
